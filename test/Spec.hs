module Main (main) where

import Control.Exception (finally)
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory, removeDirectoryRecursive)
import Test.Hspec

import FFmpeg (
    RecordConfig (RecordConfig, rcAudioDevice, rcDisplay, rcHeight, rcOutputPath, rcWidth),
    compressVideo,
    extractFrames,
    recordArgs,
    shellCommand,
 )
import GHC.IO.Exception (ExitCode (ExitFailure))
import Platform (Platform (Linux, MacOS, WindowsHost), platformFromOsString)
import Sox (soxArgs)

testDir :: FilePath
testDir = "test/output"

main :: IO ()
main = hspec $
    around_ withTestDir $ do
        describe "extractFrames" $
            it "return 1 if file doesnt exist" $
                extractFrames "ata/foo.mp4" (testDir ++ "/frame_%04d.png") 1
                    `shouldThrow` (== ExitFailure 1)
        describe "extractFrames" $
            it "writes at least one frame to disk" $ do
                extractFrames "data/foo.mp4" (testDir ++ "/frame_%04d.png") 1
                frames <- listDirectory testDir
                frames `shouldNotBe` []

        describe "compressVideo" $
            it "writes a compressed output file" $ do
                let outFile = testDir ++ "/compressed.mp4"
                compressVideo "data/foo.mp4" outFile
                exists <- doesFileExist outFile
                exists `shouldBe` True

        describe "shellCommand" $ do
            it "joins plain args unquoted" $
                shellCommand "ffmpeg" ["-i", "in.mp4", "-vf", "scale=1920:1080", "out.mp4"]
                    `shouldBe` "ffmpeg -i in.mp4 -vf scale=1920:1080 out.mp4"
            it "single-quotes args containing spaces or shell characters" $
                shellCommand "ffmpeg" ["-i", "audio=Microphone (Realtek)", "my video.mp4"]
                    `shouldBe` "ffmpeg -i 'audio=Microphone (Realtek)' 'my video.mp4'"
            it "escapes embedded single quotes" $
                shellCommand "ffmpeg" ["it's.mp4"]
                    `shouldBe` "ffmpeg 'it'\\''s.mp4'"
            it "uses the given program name" $
                shellCommand "sox" ["-d", "-t", "wav", "-"]
                    `shouldBe` "sox -d -t wav -"

        describe "platformFromOsString" $ do
            it "maps darwin to MacOS" $
                platformFromOsString "darwin" `shouldBe` Just MacOS
            it "maps linux to Linux" $
                platformFromOsString "linux" `shouldBe` Just Linux
            it "maps mingw32 to WindowsHost" $
                platformFromOsString "mingw32" `shouldBe` Just WindowsHost
            it "returns Nothing for unrecognized os strings" $
                platformFromOsString "plan9" `shouldBe` Nothing

        describe "recordArgs" $ do
            let cfg =
                    RecordConfig
                        { rcDisplay = "1"
                        , rcAudioDevice = Nothing
                        , rcWidth = 1920
                        , rcHeight = 1080
                        , rcOutputPath = "out.mp4"
                        }
            it "builds avfoundation + sox pipe args on MacOS" $
                recordArgs MacOS cfg
                    `shouldBe` [ "-thread_queue_size"
                               , "512"
                               , "-framerate"
                               , "30"
                               , "-f"
                               , "avfoundation"
                               , "-i"
                               , "1"
                               , "-thread_queue_size"
                               , "512"
                               , "-f"
                               , "wav"
                               , "-i"
                               , "pipe:0"
                               , "-vf"
                               , "scale=1920:1080"
                               , "-g"
                               , "30"
                               , "-movflags"
                               , "+frag_keyframe+empty_moov"
                               , "-pix_fmt"
                               , "yuv420p"
                               , "out.mp4"
                               ]
            it "builds x11grab + sox pipe args on Linux" $
                recordArgs Linux cfg
                    `shouldBe` [ "-thread_queue_size"
                               , "512"
                               , "-framerate"
                               , "30"
                               , "-f"
                               , "x11grab"
                               , "-i"
                               , "1"
                               , "-thread_queue_size"
                               , "512"
                               , "-f"
                               , "wav"
                               , "-i"
                               , "pipe:0"
                               , "-vf"
                               , "scale=1920:1080"
                               , "-g"
                               , "30"
                               , "-movflags"
                               , "+frag_keyframe+empty_moov"
                               , "-pix_fmt"
                               , "yuv420p"
                               , "out.mp4"
                               ]
            it "builds gdigrab + sox pipe args on WindowsHost" $
                recordArgs WindowsHost cfg
                    `shouldBe` [ "-thread_queue_size"
                               , "512"
                               , "-framerate"
                               , "30"
                               , "-f"
                               , "gdigrab"
                               , "-i"
                               , "1"
                               , "-thread_queue_size"
                               , "512"
                               , "-f"
                               , "wav"
                               , "-i"
                               , "pipe:0"
                               , "-vf"
                               , "scale=1920:1080"
                               , "-g"
                               , "30"
                               , "-movflags"
                               , "+frag_keyframe+empty_moov"
                               , "-pix_fmt"
                               , "yuv420p"
                               , "out.mp4"
                               ]

        describe "soxArgs" $ do
            it "uses the default input device when none is given" $
                soxArgs MacOS Nothing `shouldBe` ["-V1", "-d", "-t", "wav", "-"]
            it "uses coreaudio for a named device on MacOS" $
                soxArgs MacOS (Just "MacBook Air Microphone")
                    `shouldBe` ["-V1", "-t", "coreaudio", "MacBook Air Microphone", "-t", "wav", "-"]
            it "uses pulseaudio for a named device on Linux" $
                soxArgs Linux (Just "default")
                    `shouldBe` ["-V1", "-t", "pulseaudio", "default", "-t", "wav", "-"]
            it "uses waveaudio for a named device on WindowsHost" $
                soxArgs WindowsHost (Just "Microphone")
                    `shouldBe` ["-V1", "-t", "waveaudio", "Microphone", "-t", "wav", "-"]
  where
    withTestDir action =
        createDirectoryIfMissing True testDir
            `finally` action
            `finally` removeDirectoryRecursive testDir
