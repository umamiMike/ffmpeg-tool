# Revision history for haskell

## Unreleased -- 2026-10-20

Screen and microphone recording from the `ffmpego` command.

### UI Changes

* The executable is now `ffmpego` (was `haskell`).
* New `ffmpego record <output-video> [display] [audio]` command: records the
  screen with ffmpeg and the microphone with sox until Ctrl+C.
* `-h` / `--help` (and any unrecognized arguments) print a usage screen.
* Every ffmpeg run prints the full, shell-quoted command line before it
  starts, so it can be run by hand.
* Recording asks before overwriting an existing output file.
* Stopping a recording with Ctrl+C reports "Recording saved." instead of an
  error.

### Technical Changes

* `FFmpeg` moved from `app/` into a `library` component (`ffmpeg/`) so HLS can
  load it; the executable and test suite depend on the library.
* New `Platform` (platform type and OS mapping) and `Sox` (sox arguments)
  modules.
* sox writes WAV to stdout, piped into ffmpeg's stdin; `recordArgs` captures
  video only.
* New `shellCommand` and `soxArgs` functions, with tests (18 total).

## 0.1.0.0 -- YYYY-mm-dd

* First version. Released on an unsuspecting world.
