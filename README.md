# 📼 Normalize Audio Loudness Across Video Files

Batch normalize audio loudness across `.mkv`, `.mp4`, `.mov`, and `.avi` videos using **FFmpeg** and **Bash**.  
Preserves video quality by copying video streams, speeds up reprocessing with cached loudness metadata, and uses parallelization to speed up processing.

---

## ✨ Features

- Analyze audio loudness (`input_i`) without re-encoding video
- Cache analysis results to `.loudnorm.json` files
- Normalize only files significantly louder or quieter than average
- Skip already normalized files automatically
- Fully parallelize both analysis and normalization
- Control the number of concurrent processes with `--threads`
- Force fresh analysis and normalization with `--reanalyze`
- Skip confirmation prompts with `-y`
- Easy to support more media formats by editing a list

---

## 📋 Requirements

- Bash (Linux, WSL, or macOS Terminal)

Tool | Why it's needed | Install with
| --- | --- | --- |
ffmpeg | Audio analysis + normalization | sudo apt install ffmpeg
bc | Decimal math for averaging and comparisons | sudo apt install bc
awk | Text processing and float math (built-in) | Usually preinstalled
grep | Extract values from ffmpeg output | Usually preinstalled
xargs | Trim whitespace from values | Usually preinstalled
find | Recursively locate .mkv files | Usually preinstalled

---

## 🚀 Usage

Clone the repo and run:

```bash
chmod +x norm.sh
./norm.sh

```

To force reanalyze and renormalize all files:

```bash 
./norm.sh --reanalyze
```

Optional Flags

   - --threads N — Process up to N files at the same time (default: 1)
   - --reanalyze — Force fresh analysis even if .loudnorm.json exists
   - -y or --yes — Skip confirmation after analysis

```bash
./norm.sh --threads 8 -y
```
```bash
./norm.sh --threads 4
```
```bash
./norm.sh --reanalyze --threads 6
```
```bash
./norm.sh --threads 8 -y
```

## 🔍 How It Works

   1. **Scan** all .mkv files one level deep (e.g., inside ```Season 1/```, ```Season 2/```)
   2. **Analyze** loudness or load cached ```.loudnorm.json``` metadata
   3. **Calculate** the average loudness across all files
   4. **Classify** episodes into:
       - Average (no change needed)
       - Loud (normalize down)
       - Quiet (normalize up)
   5. **Prompt** you to continue before making changes (or auto-confirm with ```-y```).
   6. **Normalize** audio without touching video encoding

## 📂 Supported Media Types

You can easily adjust supported media types by editing this list in the script:
```
ALLOWED_EXTENSIONS=("mkv" "mp4" "mov" "avi")
```
Add more formats like ```webm```, ```flv```, etc. if needed.

## 🗃️ Example Output

```bash
| File Path                                          | Loudness |
-----------------------------------------------------------------
Average Files
'Season 1/Episode 1.mkv'                             |  -21.00
'Season 1/Episode 2.mkv'                             |  -21.50

Loud Files
'Season 1/Episode 3.mkv'                             |  -15.00

Quiet Files
'Season 1/Episode 4.mkv'                             |  -28.00
```

Prompt:

```bash
Do you want to continue and edit the Loud and Quiet Files? [y/N]
```

## 📂 Metadata Caching

Each video gets a .loudnorm.json after analysis, for example:

 ```
Season 1/Episode 1.mkv.loudnorm.json
```

Metadata example:

```
{
  "input_i" : "-22.30",
  "input_tp" : "-1.10",
  "input_lra" : "4.50",
  "input_thresh" : "-32.00",
  "target_offset" : "-1.70",
  "normalized": true
}
```

If the metadata exists and indicates the file is already normalized, the script skips it (unless you use --reanalyze).
### 🛡️ License

This project is licensed under the MIT License.
### 💬 Acknowledgements

   1 FFmpeg Project

   2 Inspiration from struggling to fall asleep to shows without constant remote volume adjustment. 📺
