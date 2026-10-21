module Main (main) where

import FFmpeg
import System.Environment (getArgs)

main :: IO ()
main = do
    args <- getArgs
    case args of
        ["-h"] -> putStr helpText
        ["--help"] -> putStr helpText
        ["record", out] -> record out "1" Nothing
        ["record", out, display] -> record out display Nothing
        ["record", out, display, audio] -> record out display (Just audio)
        [inputFile, outputName] -> compressVideo inputFile outputName
        _ -> putStr helpText

-- Defaults to 1920x1080. Display "1" is the macOS avfoundation index for the
-- screen on this machine. Audio is a sox device name; Nothing = sox default.
record :: FilePath -> String -> Maybe String -> IO ()
record out display audio =
    recordScreen RecordConfig
        { rcDisplay = display
        , rcAudioDevice = audio
        , rcWidth = 1920
        , rcHeight = 1080
        , rcOutputPath = out
        }

helpText :: String
helpText = unlines
    [ "ffmpego - a small ffmpeg wrapper"
    , ""
    , "Usage:"
    , "  ffmpego <input-video> <output-video>                 Compress a video"
    , "  ffmpego record <output-video> [display] [audio]      Record screen + mic (Ctrl+C to stop)"
    , "  ffmpego -h | --help                                  Show this help"
    , ""
    , "Record defaults: display 1, sox default input device, 1920x1080."
    , "Recording needs both ffmpeg (screen) and sox (microphone) on PATH."
    ]
