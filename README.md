# 📼 Normalize Audio Loudness Across Video Files

Batch normalize audio loudness across .mkv videos using FFmpeg and Bash.
Preserves video quality by copying the video stream, adjusts only files that are too loud or too quiet, and speeds up reprocessing with cached loudness metadata.

## ✨ Features

   - Analyze audio loudness (input_i) without re-encoding video

   - Cache analysis results to .loudnorm.json files

   - Normalize only files significantly louder or quieter than average

   - Skip already normalized files automatically

   - --reanalyze option to force reanalysis and normalization

   - Interactive prompt showing which files will be processed

   - Simple, portable Bash script

## 📋 Requirements

   - ffmpeg installed

   - Bash (Linux, WSL, or macOS terminal)

## 🚀 Usage
Clone the repo and run:

``` bash 
chmod +x norm.sh
./norm.sh
```

To force reanalyze and renormalize all files:

```bash 
./norm.sh --reanalyze
```

## 🔍 How It Works

   1. Scan all .mkv files one level deep (e.g., inside Season 1/, Season 2/)

   2. Analyze loudness or load cached .loudnorm.json metadata

   3. Calculate the average loudness across all files

   4. Classify episodes into:

       - Average (no change needed)

       - Loud (normalize down)

       - Quiet (normalize up)

   5. Prompt you to continue before making changes

   6. Normalize audio without touching video encoding

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
🛡️ License

This project is licensed under the MIT License.
💬 Acknowledgements

   1 FFmpeg Project

   2 Inspiration from struggling to fall asleep to shows without constant remote volume adjustment. 📺
