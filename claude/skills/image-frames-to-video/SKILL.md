---
name: image-frames-to-video
description: Use when creating video from numbered image frames in a folder, using tool.sh or direct ffmpeg. Triggers on: "make video from frames", "frames to video", "image sequence to mp4", "tool.sh --video".
---

# Image Frames to Video

## Overview

Two paths: `tool.sh` wrapper (uses `ROOT`-relative paths) or direct `ffmpeg` (absolute paths, more flexible). Direct ffmpeg is simpler for one-off or non-standard `ROOT` locations.

## Quick Reference

| Want | Use |
|------|-----|
| Quick video, frames in `~/projects/images/` | `tool.sh` |
| Absolute path or custom location | Direct `ffmpeg` |
| Multiple FPS variants at once | `tool.sh` (omit `--fps`) |
| Single FPS, full control | Direct `ffmpeg` |

## Direct ffmpeg (Recommended)

```bash
# Basic: glob all PNGs, 10fps, output to same folder
ffmpeg -r 10 -f image2 -pattern_type glob \
  -i "/path/to/frames/*.png" \
  -vcodec libx264 -crf 17 -pix_fmt yuv420p \
  "/path/to/frames/output.10.720.mp4"

# With square padding/scaling (matches tool.sh behavior)
ffmpeg -r 10 -f image2 -pattern_type glob \
  -i "/path/to/frames/*.png" \
  -vf "scale=720:720:force_original_aspect_ratio=decrease,pad=720:720:(ow-iw)/2:(oh-ih)/2" \
  -vcodec libx264 -crf 17 -pix_fmt yuv420p \
  "/path/to/frames/output.10.720.mp4"
```

**Example - this project's genart-output folder:**
```bash
ffmpeg -r 10 -f image2 -pattern_type glob \
  -i "$HOME/projects/images/genart-output/*.png" \
  -vf "scale=720:720:force_original_aspect_ratio=decrease,pad=720:720:(ow-iw)/2:(oh-ih)/2" \
  -vcodec libx264 -crf 17 -pix_fmt yuv420p \
  "$HOME/projects/images/genart-output/dragline.burst.10.720.mp4"
```

## tool.sh Wrapper

`ROOT` defaults to `~/projects/images`. All `--target` / `--destination` paths are relative to `ROOT`.

```bash
cd /path/to/image-processing

# Single FPS
./tool.sh \
  --target genart-output \
  --destination genart-output \
  --name dragline.burst-20260620193745 \
  --video --fps 10 --resolution 720

# All FPS variants (5, 10, 20, 30) - omit --fps
./tool.sh \
  --target genart-output \
  --destination genart-output \
  --name dragline.burst-20260620193745 \
  --video --resolution 720
```

Output: `$ROOT/$DESTINATION/$NAME.$FPS.$RESOLUTION.mp4`

**tool.sh limitations:**
- Hardcoded to `*.png` (not `--suffix` configurable for video)
- Requires frames in `$ROOT`-relative path
- `--verbose` prints the ffmpeg command before running

## Frame Naming Patterns

This project uses: `{name}.frame-NNNN.png` (4-digit zero-padded)

ffmpeg glob `*.png` handles any naming as long as filenames sort correctly alphabetically.

## Common Mistakes

- `tool.sh`: forgetting `ROOT` isn't set → defaults to `~/projects/images`, may not match
- ffmpeg: output file in same glob dir → ffmpeg may try to encode itself mid-run; use a subdirectory or explicit name that won't match `*.png`
- Resolution not even → libx264 requires even dimensions; the padding filter handles this
