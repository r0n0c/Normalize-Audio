# Normalize-Audio
Batch normalize audio loudness across .mkv videos using FFmpeg and Bash. Preserves video streams, caches loudness analysis in JSON, and only adjusts files that are too loud or quiet. Supports fast re-runs with a --reanalyze option.
