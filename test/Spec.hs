module Main (main) where

import Test.Hspec
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory, removeDirectoryRecursive)
import Control.Exception (finally)

import FFmpeg (extractFrames, compressVideo)
import GHC.IO.Exception (ExitCode(ExitFailure))

testDir :: FilePath
testDir = "test/output"

main :: IO ()
main = hspec $
  around_ withTestDir $ do
    describe "extractFrames" $
      it "return 1 if file doesnt exist" $ do
        extractFrames "ata/foo.mp4" (testDir ++ "/frame_%04d.png") 1        -- frames <- listDirectory testDir
         `shouldThrow` (== ExitFailure 1)
        -- frames `shouldBe` []
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
  where
    withTestDir action =
      createDirectoryIfMissing True testDir
        `finally` action
        `finally` removeDirectoryRecursive testDir
