# haskell-sandbox

Personal Haskell learning sandbox. Cabal project, no Stack/Nix files inside
the repo itself (GHC/cabal/ffmpeg are provided externally via nix
home-manager).

## Requirements

- GHC + cabal-install (matching `haskell-sandbox.cabal`'s `base ^>=4.20.2.0`)
- `ffmpeg` on `$PATH` (used by the `haskell` executable and its tests)
- `cabal update` run at least once, so the Hackage index is available for
  `typed-process`, `directory`, and `hspec`

## Layout

```
haskell-sandbox.cabal   Package/build definition
app/
  Main.hs                Entry point for the `haskell` executable
  FFmpeg.hs               FFmpeg wrapper module (extractFrames, compressVideo)
  RssiTimeline.hs         Entry point for the `rssi-timeline` executable
  Nums.hs                 Scratch file — not wired into the .cabal file, not built
data/
  foo.mp4                 Sample clip used by the FFmpeg tests
test/
  Spec.hs                 Hspec test suite for FFmpeg.hs
```

## Executables

### `haskell`

Compresses a video via `ffmpeg`, using `FFmpeg.compressVideo`.

```sh
cabal run haskell -- <input-video> <output-video>
```

Run with no arguments (or the wrong count) prints `Help`.

Note: `FFmpeg.hs` also defines `extractFrames` (pulls frames out of a video
at a given fps), but it isn't currently exposed through `Main.hs` — it's
only exercised by the test suite.

### `rssi-timeline`

Turns a janky RSSI polling log (one line per ~1s poll, no timestamps) into
an SVG timeline chart.

```sh
cabal run rssi-timeline -- <path/to/info.log> [output.svg]
```

Defaults to `rssi_timeline.svg` if no output path is given. Errors out if
the log has no `RSSI : <dBm>` lines.

## Tests

```sh
cabal test
```

`test/Spec.hs` is a smoke test for `FFmpeg.hs`'s two functions
(`extractFrames`, `compressVideo`), run against a real video via a real
`ffmpeg` call — no mocking. It writes into a scratch `test/output/`
directory that gets cleaned up after each run.

**Currently broken:** the spec still points at `"foo.mp4"`, but the sample
clip lives at `data/foo.mp4` now — the paths need updating to
`"data/foo.mp4"` before `cabal test` will pass again.
