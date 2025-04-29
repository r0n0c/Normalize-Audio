#!/bin/bash
set -euo pipefail

# Optional flags
REANALYZE=false
THREADS=1
CONFIRM=false
SEARCH_PATH="."

# Allowed media file extensions (space-separated, no dot)
ALLOWED_EXTENSIONS=("mkv" "mp4" "mov" "avi")

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --reanalyze)
      REANALYZE=true
      shift
      ;;
    --threads)
      THREADS="$2"
      shift 2
      ;;
    -y|--yes)
      CONFIRM=true
      shift
      ;;
    -p|--path)
      SEARCH_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Declare associative array for file:loudness mapping
declare -A loudness_map

echo "🔍 Scanning media files under '$SEARCH_PATH'"

# Build find condition dynamically
FIND_CONDITION=""
for ext in "${ALLOWED_EXTENSIONS[@]}"; do
  FIND_CONDITION+="\\( -iname '*.${ext}' ! -iname '*.loudnorm.json' \\) -o "
done
FIND_CONDITION=${FIND_CONDITION::-4}

# Correct find structure
echo "DEBUG: Running find command:"
echo "find "$SEARCH_PATH" \( -type f -a \( $FIND_CONDITION \) \) -print0"

mapfile -d '' -t media_files < <(find "$SEARCH_PATH" \( -type f -a \( $FIND_CONDITION \) \) -print0)

if [[ ${#media_files[@]} -eq 0 ]]; then
  echo "❌ No media files found to process."
  exit 1
fi

echo "📈 Starting parallel loudness analysis with $THREADS thread(s)..."

# Parallel analysis
pids=()
for file in "${media_files[@]}"; do
  (
    meta_file="${file}.loudnorm.json"
    if [[ "$REANALYZE" == false && -f "$meta_file" ]]; then
      echo "Using cached analysis: $meta_file"
    else
      echo "Analyzing: $file"
      stats=$(ffmpeg -hide_banner -loglevel error -i "$file" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2>&1)
      echo "$stats" | sed '$ s/}$/,\n  "normalized": false\n}/' > "$meta_file"
    fi
  ) &
  pids+=($!)

  if (( ${#pids[@]} >= THREADS )); then
    wait -n
    pids=("${pids[@]:1}")
  fi
done
wait

# Build loudness map
for file in "${media_files[@]}"; do
  meta_file="${file}.loudnorm.json"
  if [[ -f "$meta_file" ]]; then
    stats=$(<"$meta_file")
    iI=$(echo "$stats" | awk -F': ' '/"input_i"/ { gsub(/[",]/, "", $2); print $2 }')

    if [[ -n "$iI" && "$iI" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      loudness_map["$file"]="$iI"
    else
      echo "❌ Could not parse input_i for $file"
    fi
  else
    echo "⚠️ Warning: Missing metadata for $file"
  fi
done

# Calculate average loudness
sum=0
count=0
for i in "${loudness_map[@]}"; do
  sum=$(echo "$sum + $i" | bc)
  count=$((count + 1))
done

if [[ "$count" -eq 0 ]]; then
  echo "❌ No valid loudness data found. Exiting."
  exit 1
fi

avg=$(echo "scale=2; $sum / $count" | bc)

echo -e "\n📊 Average loudness across files: $avg LUFS\n"
printf "| %-80s | %8s |\n" "File Path" "Loudness"
printf -- "-%.0s" {1..95}; echo

average_files=()
loud_files=()
quiet_files=()

for file in "${!loudness_map[@]}"; do
  iI="${loudness_map[$file]}"
  diff=$(echo "$iI - $avg" | bc | awk '{print ($1 < 0) ? -$1 : $1}')

  if (( $(echo "$diff <= 1.0" | bc -l) )); then
    average_files+=("$file:$iI")
  elif (( $(echo "$iI < $avg" | bc -l) )); then
    quiet_files+=("$file:$iI")
  else
    loud_files+=("$file:$iI")
  fi
done

print_group() {
  group_name=$1
  shift
  files=("$@")
  if [[ ${#files[@]} -gt 0 ]]; then
    echo ""
    echo "$group_name Files"
    for f in "${files[@]}"; do
      path="${f%%:*}"
      lvl="${f##*:}"
      printf "'%-80s' | %8s\n" "$path" "$lvl"
    done
  fi
}

print_group "Average" "${average_files[@]}"
print_group "Loud" "${loud_files[@]}"
print_group "Quiet" "${quiet_files[@]}"

# Confirm before proceeding
if [[ "$CONFIRM" == false ]]; then
  echo ""
  read -rp "Do you want to continue and edit the Loud and Quiet Files? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborting."; exit 0 ;;
  esac
else
  echo "✅ Auto-confirm enabled. Proceeding..."
fi

# Parallel normalization
echo "🔧 Starting parallel normalization with $THREADS thread(s)..."

pids=()
for file in "${!loudness_map[@]}"; do
  (
    iI="${loudness_map[$file]}"
    diff=$(echo "$iI - $avg" | bc | awk '{print ($1 < 0) ? -$1 : $1}')

    if (( $(echo "$diff <= 1.0" | bc -l) )); then
      echo "Skipping $file (within 1 LUFS of average)"
      exit 0
    fi

    if [[ "$REANALYZE" == false ]] && grep -q '"normalized": true' "${file}.loudnorm.json"; then
      echo "✅ Already normalized: $file — skipping"
      exit 0
    fi

    echo "🔧 Normalizing $file (diff = $diff LUFS)"
    stats=$(<"${file}.loudnorm.json")
    iTP=$(echo "$stats" | grep '"input_tp"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')
    iLRA=$(echo "$stats" | grep '"input_lra"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')
    iThresh=$(echo "$stats" | grep '"input_thresh"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')
    offset=$(echo "$stats" | grep '"target_offset"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')

    out="${file%.mkv}-matched.mkv"

    if ffmpeg -hide_banner -loglevel error -i "$file" -c:v copy -af "loudnorm=I=$avg:TP=-1.5:LRA=11:measured_I=$iI:measured_TP=$iTP:measured_LRA=$iLRA:measured_thresh=$iThresh:offset=$offset:linear=true:print_format=summary" "$out"; then
      if grep -q '"normalized":' "${file}.loudnorm.json"; then
        sed -i 's/"normalized": *false/"normalized": true/' "${file}.loudnorm.json"
      else
        sed -i '$ s/}/,\n  "normalized": true\n}/' "${file}.loudnorm.json"
      fi
    else
      echo "❌ Normalization failed for $file"
    fi
  ) &
  pids+=($!)

  if (( ${#pids[@]} >= THREADS )); then
    wait -n
    pids=("${pids[@]:1}")
  fi
done

wait

echo -e "\n✅ Normalization complete."
