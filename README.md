# Normalize-Audio

Normalize the volume of `.mkv`, `.mp4`, `.mov`, or `.avi` files using `ffmpeg`'s `loudnorm` filter. Great for watching shows without constantly adjusting the volume.Preserves video quality by copying video streams, speeds up reprocessing with cached loudness metadata, and uses parallelization to speed up processing.

## Features

- 🔍 Recursively finds all supported media files under a given path
- 📈 Runs a loudness analysis pass on each media file (`input_i`)
- 📝 Cache analysis results to `.loudnorm.json` files
- 🧮 Calculates the average integrated loudness (LUFS) 
- 🧘‍♂️ Only normalizes files that differ by more than 1 LUFS
- ⚡ Runs analysis and normalization in parallel using `--threads`
- 🧠 Saves per-file JSON metadata to skip re-analysis unless `--reanalyze` is specified
- 📁 Supports complex folder structures (e.g., Season folders)
- ✅ CLI flags for customization and automation

## Requirements

Tool | Why it's needed | Install with
| --- | --- | --- |
ffmpeg | Audio analysis + normalization | sudo apt install ffmpeg
bc | Decimal math for averaging and comparisons | sudo apt install bc
awk | Text processing and float math (built-in) | Usually preinstalled
grep | Extract values from ffmpeg output | Usually preinstalled
xargs | Trim whitespace from values | Usually preinstalled
find | Recursively locate .mkv files | Usually preinstalled

Clone the repo and run:

```bash
chmod +x norm.sh
./norm.sh

## Usage

```bash
./norm.sh [options]
```

### Options

| Flag            | Description                                                                |
|------------------|----------------------------------------------------------------------------|
| `-p <path>`      | Path to start scanning (default: `.`)                                      |
| `--threads <n>`  | Number of files to process in parallel (default: `1`)                      |
| `--reanalyze`    | Re-analyze loudness even if JSON metadata is present                       |
| `-y` or `--yes`  | Skip confirmation prompt before normalization                              |

### Example

```bash
./norm.sh -p "/mnt/media/SHOW" --threads 4 --reanalyze -y
```

This will scan the following structure:

```
SHOW/
├── Season 1/
│   ├── SHOW - S01E01 - EPISODE.mkv
│   └── SHOW - S01E02 - EPISODE.mkv
├── Season 2/
│   ├── SHOW - S02E01 - EPISODE.mkv
│   └── ...
```

It recursively scans all subdirectories under the specified path to find valid media files (e.g., inside Season folders).

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

## How It Works

1. Finds all files matching allowed extensions (excluding `.loudnorm.json`)
2. Uses `ffmpeg` with `loudnorm` to analyze volume, outputting JSON
3. Caches results in `filename.mkv.loudnorm.json`
4. Calculates average LUFS across all files
5. Normalizes only those with >1 LUFS deviation
6. Writes new `-matched.mkv` output file next to original
7. Marks normalized files in metadata

## Version

**v1.0.0**

---

Licensed under MIT. Contributions welcome!

### 💬 Acknowledgements

   1 FFmpeg Project

   2 Inspiration from struggling to fall asleep to shows without constant remote volume adjustment. 📺

