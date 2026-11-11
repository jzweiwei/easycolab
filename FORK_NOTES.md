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

Owner clarification (2026-11-11): the local changes were minor, in
two areas only, and only one is worth porting:

1. Google Drive mount experiments for model weights - DISCARD.
   Conclusion already reached by testing: even when mounting works,
   Drive reads at ~100 MB/s and weights still have to be copied to
   local disk, which is slower than simply re-downloading to local
   disk (~700 MB/s). This fork follows the re-download approach.
2. A prompt toolbar in the video-generation UI - PORT THIS.
   Located in the legacy monolith around the "Cinema Prompt & Lens
   Workbench" / master cinema-camera preset tabs (legacy
   EasyColabStudio.swift, roughly lines 8240-8700). No equivalent
   exists in current upstream Sources/. Porting target:
   macos_app/Sources/MainStudioView+Workspace.swift.

## Planned work on this branch

- Port the local Mac customisations onto the current upstream structure.
- Add MiniMax-H3-Image (text-to-image + image editing) via the
  DiffSynth minimax_h3_image pipeline, reusing the H3 video
  text-encoder weights.

## Upstream sync rule (owner, 2026-11-11)

Upstream (wy51ai/easycolab) is not followed blindly. When upstream
pushes an update or new feature, evaluate whether it is useful /
needed for the owner; if it is, apply the same update to this fork
(weiwei-custom, preserving our prompt workbench and H3-Image work,
with a build check after merging) and to the Mac project copy at
/Users/weiwei/AI/mygpu/repo.
