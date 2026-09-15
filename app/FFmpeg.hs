module FFmpeg where

import System.Process.Typed
import System.Exit (exitFailure)

import Control.Exception
import Control.Monad (unless)
import Data.String (fromString)
import System.Directory (doesFileExist)

data FFmpegError = FFmpegError String deriving (Show)
instance Exception FFmpegError

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
    
    result <- runProcess (proc "ffmpeg" args)
    case result of
        ExitSuccess -> putStrLn "finished"
        ExitFailure n ->
            throwIO $ FFmpegError $ "Failed with code: " ++ show n
