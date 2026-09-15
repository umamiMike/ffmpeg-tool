module Main (main) where

import FFmpeg
import System.Environment (getArgs)

main :: IO ()
main = do
    args <- getArgs
    case args of
        [inputFile, outputName] -> compressVideo inputFile outputName
        _ -> putStrLn "Help"
