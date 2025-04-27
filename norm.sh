#!/bin/bash
set -euo pipefail
# Optional flag to re-analyze and re-normalize all files
REANALYZE=false
[[ "${1:-}" == "--reanalyze" ]] && REANALYZE=true

# Declare an associative array to store each file's loudness (input_i value)
declare -A loudness_map

echo "Scanning all MKVs..."

# Pass 1: Find all .mkv files one level deep and analyze loudness
mapfile -t mkv_files < <(find . -mindepth 2 -maxdepth 2 -type f -name "*.mkv")

for file in "${mkv_files[@]}"; do
    meta_file="${file}.loudnorm.json"

    if [[ "$REANALYZE" == false && -f "$meta_file" ]]; then
      echo "Using cached analysis: $meta_file"
      stats=$(<"$meta_file")
    else
      echo "Analyzing: $file"
      stats=$(ffmpeg -i "$file" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2>&1)
      echo "$stats" | sed '$ s/}$/,\n  "normalized": false\n}/' > "$meta_file"
    fi

  iI=$(echo "$stats" | awk -F': ' '/"input_i"/ { gsub(/[",]/, "", $2); print $2 }')

  if ! [[ "$iI" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "❌ Could not parse input_i for file: $file"
    continue
  fi

  loudness_map["$file"]="$iI"
done

# Calculate average loudness across all scanned files
sum=0
count=0

for i in "${loudness_map[@]}"; do
  sum=$(echo "$sum + $i" | bc)       # Running total of loudness
  count=$((count + 1))               # Count of files
done

# Compute average loudness to 2 decimal places
avg=$(echo "scale=2; $sum / $count" | bc)

# Validate that avg is a number before continuing
if ! [[ "$avg" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
  echo "❌ Average loudness calculation failed (invalid value: '$avg')."
  exit 1
fi

echo "Average loudness across files: $avg LUFS"

echo ""
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

# Helper to print groups
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

echo ""
read -rp "Do you want to continue and edit the Loud and Quiet Files? [y/N] " response
case "$response" in
  [yY][eE][sS]|[yY]) ;;
  *) echo "Aborting."; exit 0 ;;
esac


# Pass 2: Normalize only files that differ significantly from the average
for file in "${!loudness_map[@]}"; do
  iI="${loudness_map[$file]}"        # Integrated loudness for this file

  # Calculate absolute difference from average
  diff=$(echo "$iI - $avg" | bc | awk '{print ($1 < 0) ? -$1 : $1}')

  # Output filename (same folder, suffixed with -matched.mkv)
  out="${file%.mkv}-matched.mkv"

  # If loudness is more than 1 LUFS from average, normalize it
  if (( $(echo "$diff > 1.0" | bc -l) )); then
    # Skip if already normalized
    if [[ "$REANALYZE" == false ]] && grep -q '"normalized": true' "${file}.loudnorm.json"; then
      echo "✅ Already normalized: $file — skipping"
      continue
    fi
    echo "Normalizing $file (diff = $diff)"

    # Re-analyze full loudnorm stats needed for precise second pass
    stats=$(<"${file}.loudnorm.json")

    # Extract detailed metrics from first pass
    iTP=$(echo "$stats" | grep '"input_tp"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')
    iLRA=$(echo "$stats" | grep '"input_lra"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')
    iThresh=$(echo "$stats" | grep '"input_thresh"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')
    offset=$(echo "$stats" | grep '"target_offset"' | sed -E 's/.*:\s*"(-?[0-9.]+)".*/\1/')

    if [[ -z "$iTP" || -z "$iLRA" || -z "$iThresh" || -z "$offset" ]]; then
      echo "❌ Missing one or more measured values in: $file"
      continue
    fi

    # Second pass with measured values applied
    if ffmpeg -i "$file" -c:v copy -af "loudnorm=I=$avg:TP=-1.5:LRA=11:measured_I=$iI:measured_TP=$iTP:measured_LRA=$iLRA:measured_thresh=$iThresh:offset=$offset:linear=true:print_format=summary" "$out"; then
      if grep -q '"normalized":' "${file}.loudnorm.json"; then
        sed -i 's/"normalized": *false/"normalized": true/' "${file}.loudnorm.json"
      else
        sed -i '$ s/}/,\n  "normalized": true\n}/' "${file}.loudnorm.json"
      fi
    else
      echo "❌ Normalization failed for $file"
    fi

    # Mark as normalized in metadata, or create a the field
    if grep -q '"normalized":' "${file}.loudnorm.json"; then
      # Replace existing normalized field
      sed -i 's/"normalized": *false/"normalized": true/' "${file}.loudnorm.json"
    else
      # Append new field before closing }
      sed -i '$ s/}/,\n  "normalized": true\n}/' "${file}.loudnorm.json"
    fi


  else
    echo "Skipping $file (within 1 LUFS of average)"
  fi
done
