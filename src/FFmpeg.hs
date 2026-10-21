module FFmpeg where

import System.Exit (exitFailure)
import System.Process.Typed

import Control.Exception
import Control.Monad (unless)
import Data.Char (isAlphaNum, toLower)
import Sox (soxArgs)
import System.Directory (doesFileExist)
import System.IO (hFlush, stdout)
import System.Info (os)

import Platform (Platform (Linux, MacOS, WindowsHost), platformFromOsString)

data FFmpegError = FFmpegError String deriving (Show)
instance Exception FFmpegError

-- Renders a program call as a line you can paste into a shell.
-- Args with anything outside a safe character set are single-quoted.
shellCommand :: String -> [String] -> String
shellCommand program args = unwords (program : map quote args)
  where
    quote a
        | not (null a) && all safe a = a
        | otherwise = "'" ++ concatMap escape a ++ "'"
    safe c = isAlphaNum c || c `elem` "-_./=:+,%@"
    escape '\'' = "'\\''"
    escape c = [c]

-- Extract frames from video
extractFrames :: FilePath -> FilePath -> Int -> IO ()
extractFrames inputFile outputPattern fps = do
    putStrLn $ "Extracting frames from: " ++ inputFile

    let args =
            [ "-i"
            , inputFile
            , "-vf"
            , "fps=" ++ show fps -- frames per second
            , "-q:v"
            , "2" -- quality
            , outputPattern -- e.g. "frame_%04d.png"
            ]

    exists <- doesFileExist inputFile
    unless exists $ do
        putStrLn "nope"
        exitFailure

    putStrLn (shellCommand "ffmpeg" args)
    result <- runProcess (proc "ffmpeg" args)

    case result of
        ExitSuccess -> putStrLn "Frames extracted!"
        ExitFailure n ->
            throwIO $ FFmpegError $ "Failed with code: " ++ show n

-- -- Compress video
compressVideo :: FilePath -> FilePath -> IO ()
compressVideo inputFile outputName = do
    putStrLn $ "Compressing  " ++ inputFile

    let args =
            [ "-i"
            , inputFile
            , outputName
            ]

    exists <- doesFileExist inputFile
    unless exists $ do
        putStrLn "file doesnt exist"
        exitFailure

    putStrLn (shellCommand "ffmpeg" args)
    result <- runProcess (proc "ffmpeg" args)
    case result of
        ExitSuccess -> putStrLn "finished"
        ExitFailure n ->
            throwIO $ FFmpegError $ "Failed with code: " ++ show n

-- Screen recording
detectPlatform :: IO Platform
detectPlatform = case platformFromOsString os of
    Just p -> pure p
    Nothing -> throwIO $ FFmpegError $ "Unsupported platform: " ++ os

data RecordConfig = RecordConfig
    { rcDisplay :: String -- platform-specific display selector (e.g. avfoundation/x11grab device)
    , rcAudioDevice :: Maybe String -- sox input device name; Nothing = sox default (-d)
    , rcWidth :: Int
    , rcHeight :: Int
    , rcOutputPath :: FilePath
    }
    deriving (Show, Eq)

scaleFilter :: RecordConfig -> String
scaleFilter cfg = "scale=" ++ show (rcWidth cfg) ++ ":" ++ show (rcHeight cfg)

-- Builds the ffmpeg args for a given platform + config. Video comes from the
-- platform's screen grabber; audio arrives as WAV on stdin from sox.
-- Pure, so it's unit-testable without a real display/microphone.
recordArgs :: Platform -> RecordConfig -> [String]
recordArgs platform cfg =
    [ "-thread_queue_size"
    , "512"
    , "-framerate"
    , "30"
    ]
        ++ videoInput platform
        ++ [ "-thread_queue_size"
           , "512"
           , "-f"
           , "wav"
           , "-i"
           , "pipe:0"
           , "-vf"
           , scaleFilter cfg
           , "-g"
           , "30"
           , "-movflags"
           , "+frag_keyframe+empty_moov"
           , "-pix_fmt"
           , "yuv420p"
           , rcOutputPath cfg
           ]
  where
    videoInput MacOS = ["-f", "avfoundation", "-i", rcDisplay cfg]
    videoInput Linux = ["-f", "x11grab", "-i", rcDisplay cfg]
    videoInput WindowsHost = ["-f", "gdigrab", "-i", rcDisplay cfg]

-- Records screen (ffmpeg) + microphone (sox, piped into ffmpeg) until
-- interrupted with Ctrl+C. Both children get the Ctrl+C and handle it
-- themselves (delegate_ctlc): sox stops, the pipe closes, ffmpeg finalizes.
recordScreen :: RecordConfig -> IO ()
recordScreen cfg = do
    platform <- detectPlatform
    -- ffmpeg can't ask about overwriting (its stdin is the sox pipe) and
    -- silently exits 0, so ask here and pass -y on yes.
    alreadyExists <- doesFileExist (rcOutputPath cfg)
    proceed <- if alreadyExists then confirmOverwrite (rcOutputPath cfg) else pure True
    if not proceed
        then putStrLn "Not overwriting. Nothing recorded."
        else runRecording platform alreadyExists cfg

confirmOverwrite :: FilePath -> IO Bool
confirmOverwrite path = do
    putStr $ path ++ " exists. Overwrite? [y/N] "
    hFlush stdout
    answer <- getLine
    pure (map toLower answer `elem` ["y", "yes"])

runRecording :: Platform -> Bool -> RecordConfig -> IO ()
runRecording platform overwrite cfg = do
    let sArgs = soxArgs platform (rcAudioDevice cfg)
        fArgs = (if overwrite then ("-y" :) else id) (recordArgs platform cfg)
    putStrLn $ "Recording to: " ++ rcOutputPath cfg
    putStrLn $ shellCommand "sox" sArgs ++ " | " ++ shellCommand "ffmpeg" fArgs
    let soxProc = setDelegateCtlc True $ setStdout createPipe $ proc "sox" sArgs
    (ffResult, soxResult) <- withProcessWait soxProc $ \sox -> do
        let ffProc =
                setDelegateCtlc True $
                    setStdin (useHandleClose (getStdout sox)) $
                        proc "ffmpeg" fArgs
        ffResult <- runProcess ffProc
        soxResult <- waitExitCode sox
        pure (ffResult, soxResult)
    outExists <- doesFileExist (rcOutputPath cfg)
    let saved = do
            case soxResult of
                ExitFailure n -> putStrLn $ "Warning: sox exited with code " ++ show n
                ExitSuccess -> pure ()
            putStrLn "Recording saved."
    case ffResult of
        ExitSuccess -> saved
        -- ffmpeg exits 255 after finalizing the file on Ctrl+C.
        ExitFailure 255 | outExists -> saved
        ExitFailure n ->
            throwIO $ FFmpegError $ "ffmpeg failed with code: " ++ show n
