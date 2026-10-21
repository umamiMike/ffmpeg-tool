# ffmpeg-tool

Personal Haskell learning sandbox. Cabal project, no Stack/Nix files inside
the repo itself (GHC/cabal/ffmpeg are provided externally via nix
home-manager).

## Requirements

- GHC + cabal-install (matching `haskell-sandbox.cabal`'s `base ^>=4.20.2.0`)
- `ffmpeg` on `$PATH` (used by the `ffmpego` executable and its tests)
- `sox` on `$PATH` (records the microphone for `ffmpego record`)
- `cabal update` run at least once, so the Hackage index is available for
  `typed-process`, `directory`, and `hspec`

## Layout

```
haskell-sandbox.cabal   Package/build definition
ffmpeg/
  FFmpeg.hs               FFmpeg wrapper module, built as the package's
                          `library` (extractFrames, compressVideo,
                          recordScreen, recordArgs, platform detection)
app/
  Main.hs                Entry point for the `ffmpego` executable
  RssiTimeline.hs         Entry point for the `rssi-timeline` executable
  Nums.hs                 Scratch file — not wired into the .cabal file, not built
data/
  foo.mp4                 Sample clip used by the FFmpeg tests
test/
  Spec.hs                 Hspec test suite for FFmpeg.hs
```

## Executables

### `ffmpego`

Command-line front end for the `FFmpeg` library.

```
Usage:
  ffmpego <input-video> <output-video>                 Compress a video
  ffmpego record <output-video> [display] [audio]      Record screen + mic (Ctrl+C to stop)
  ffmpego -h | --help                                  Show this help
```

Running it with no arguments, or with arguments that match none of the
above, prints the same help.

#### Compress

```sh
cabal run ffmpego -- <input-video> <output-video>
```

Uses `FFmpeg.compressVideo`. Because `record` is checked first, an input
file literally named `record` must be passed as `./record`.

#### Record

```sh
cabal run ffmpego -- record test-record.mp4                              # display 1, default mic
cabal run ffmpego -- record test-record.mp4 1 "MacBook Air Microphone"   # named mic
```

Uses `FFmpeg.recordScreen` at 1920x1080 (not configurable from the command
line). ffmpeg captures the screen, and sox captures the microphone and pipes
WAV audio into ffmpeg's stdin, which combines both into one file. Before
recording it prints the full `sox ... | ffmpeg ...` command so it can be
run by hand.

- `[display]` (default `1`) is an ffmpeg screen device. On macOS it is an
  avfoundation index; list yours with
  `ffmpeg -hide_banner -f avfoundation -list_devices true -i ""`.
- `[audio]` (default: sox's default input device, `-d`) is a sox device
  name, passed with the platform's sox driver (`coreaudio` on macOS,
  `pulseaudio` on Linux, `waveaudio` on Windows).

Press Ctrl+C to stop. On first run macOS asks to allow screen recording
and microphone access for the terminal app.

#### Installing as a standalone command

To run it as `ffmpego` instead of `cabal run ffmpego --`:

```sh
cabal install exe:ffmpego --overwrite-policy=always
ffmpego <input-video> <output-video>
```

- The binary is copied into cabal's install dir. With cabal-install 3.16 and
  no `~/.cabal` directory, that is `~/.local/bin`, which must be on `$PATH`.
- `--overwrite-policy=always` lets you re-run the install after code
  changes. Without it, a second install fails because the file already
  exists.

To build without installing, run `cabal build exe:ffmpego`, then
`cabal list-bin ffmpego` to print the path of the built binary inside
`dist-newstyle/`.

#### Library notes

- `extractFrames` pulls frames out of a video at a given fps. It is not
  exposed through `Main.hs`; only the test suite uses it.
- `recordScreen` records the screen and microphone to a file, configured by
  a `RecordConfig` (display, optional sox audio device, width, height,
  output path). It detects the platform at runtime and picks the matching
  capture backends:

  | Platform | Video (ffmpeg) | Audio (sox driver) |
  |----------|----------------|--------------------|
  | macOS    | avfoundation   | coreaudio          |
  | Linux    | x11grab        | pulseaudio         |
  | Windows  | gdigrab        | waveaudio          |

  sox's stdout is connected to ffmpeg's stdin. Recording runs until
  interrupted with Ctrl+C; both processes handle the Ctrl+C themselves
  (sox stops, the pipe closes, ffmpeg finalizes the file). The argument
  lists are built by the pure functions `recordArgs` and `soxArgs`, so they
  can be tested without a display or microphone.

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

`test/Spec.hs` has 10 cases:

| Function               | Cases | Kind |
|------------------------|-------|------|
| `extractFrames`        | 2     | Real `ffmpeg` call on `data/foo.mp4`: missing input exits with code 1; valid input writes at least one frame |
| `compressVideo`        | 1     | Real `ffmpeg` call on `data/foo.mp4`: writes the output file |
| `platformFromOsString` | 4     | Pure: darwin, linux, mingw32, and an unknown OS string |
| `recordArgs`           | 3     | Pure: exact argument list for macOS, Linux, and Windows |

The ffmpeg cases use no mocking. They write into a scratch `test/output/`
directory that gets cleaned up after each run. `recordScreen` itself has no
test because it needs a real display and microphone.
