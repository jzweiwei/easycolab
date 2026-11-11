# Personal fork notes

This is jzweiwei's personal fork of wy51ai/easycolab, for personal use.

- Upstream: https://github.com/wy51ai/easycolab
- Base commit at fork time: fb5a73b (master, VERSION 1.1.0)
- License: Apache License 2.0. The original LICENSE file and all
  upstream copyright / attribution notices are retained unchanged.
  See LICENSE for the full terms.
- Modified files in this fork will carry a note that they were changed,
  as required by Apache-2.0 section 4(b).

## Local custom version (not yet merged)

The owner's working Mac app was customised from an early (2026-11-08,
v1.0.2-era) upstream snapshot, when macos_app was a single-file
EasyColabStudio.swift. Upstream refactored that code into
macos_app/Sources/ on 2026-11-10, so the local changes are NOT copied
over master blindly; they will be ported file-by-file onto this branch.

Local snapshot location (owner's Mac mini):
/Users/weiwei/AI/EasyColab  (plus backups/v1.0.2_working_backup)

## Planned work on this branch

- Port the local Mac customisations onto the current upstream structure.
- Add MiniMax-H3-Image (text-to-image + image editing) via the
  DiffSynth minimax_h3_image pipeline, reusing the H3 video
  text-encoder weights.
