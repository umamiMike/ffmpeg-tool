module Main (main) where

-- Turns a janky RSSI polling log into an SVG timeline chart.
--
-- Log format: one line per ~1-second poll, either
--     RSSI                 : -64 dBm
-- or a plain echoed text message (e.g. "walking up the stairs").
-- There are no timestamps in the log, so line order is used as elapsed
-- seconds (1 poll/sec).
--
-- Usage: rssi-timeline <path/to/info.log> [output.svg]

import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Data.List (isInfixOf)
import Data.Char (isSpace)
import Text.Read (readMaybe)
import Text.Printf (printf)

data Sample = Rssi Int Int        -- second, dBm
            | Message Int String  -- second, text

parseLine :: Int -> String -> Maybe Sample
parseLine sec line
  | null trimmed = Nothing
  | "RSSI" `isInfixOf` line =
      case break (== ':') line of
        (_, ':':rest) ->
          let tok = takeWhile (not . isSpace) (dropWhile isSpace rest)
          in Rssi sec <$> readMaybe tok
        _ -> Nothing
  | otherwise = Just (Message sec trimmed)
  where
    trimmed = dropWhile isSpace . reverse . dropWhile isSpace . reverse $ line

parseLog :: String -> [Sample]
parseLog contents =
  [ s | (i, line) <- zip [0 ..] (lines contents)
      , Just s <- [parseLine i line]
  ]

rssiPoints :: [Sample] -> [(Int, Int)]
rssiPoints samples = [(s, v) | Rssi s v <- samples]

messages :: [Sample] -> [(Int, String)]
messages samples = [(s, t) | Message s t <- samples]

-- SVG rendering

-- all of these are declared as Doubles simultaneously
width, height, marginLeft, marginRight, marginTop, marginBottom :: Double
width = 1400
height = 600
marginLeft = 60
marginRight = 20
marginTop = 30
marginBottom = 140

plotWidth, plotHeight :: Double
plotWidth = width - marginLeft - marginRight
plotHeight = height - marginTop - marginBottom

renderSvg :: [(Int, Int)] -> [(Int, String)] -> String
renderSvg points msgs =
  unlines $
    [ printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%.0f\" height=\"%.0f\" viewBox=\"0 0 %.0f %.0f\">" width height width height
    , "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>"
    , printf "<text x=\"%.0f\" y=\"20\" font-family=\"sans-serif\" font-size=\"16\" text-anchor=\"middle\">Wi-Fi RSSI over time</text>" (width / 2)
    ]
    ++ gridLines
    ++ axisLabels
    ++ [polyline]
    ++ concatMap messageMarker msgs
    ++ ["</svg>"]
  where
    secs = map (fromIntegral . fst) points :: [Double]
    vals = map (fromIntegral . snd) points :: [Double]
    maxSec = if null secs then 1 else maximum secs
    minVal = if null vals then -100 else minimum vals - 2
    maxVal = if null vals then 0 else maximum vals + 2

    xScale s = marginLeft + (s / maxSec) * plotWidth
    yScale v = marginTop + plotHeight - ((v - minVal) / (maxVal - minVal)) * plotHeight

    polyline =
      let pts = unwords [printf "%.1f,%.1f" (xScale s) (yScale v) | (s, v) <- zip secs vals]
      in printf "<polyline points=\"%s\" fill=\"none\" stroke=\"#1f77b4\" stroke-width=\"1.5\"/>" pts

    yTicks = [minVal, minVal + (maxVal - minVal) / 4 .. maxVal]
    gridLines =
      [ printf "<line x1=\"%.1f\" y1=\"%.1f\" x2=\"%.1f\" y2=\"%.1f\" stroke=\"#ddd\" stroke-width=\"1\"/>"
          marginLeft (yScale v) (marginLeft + plotWidth) (yScale v)
      | v <- yTicks
      ]

    axisLabels =
      [ printf "<text x=\"%.1f\" y=\"%.1f\" font-family=\"sans-serif\" font-size=\"11\" text-anchor=\"end\">%.0f dBm</text>"
          (marginLeft - 6) (yScale v + 4) v
      | v <- yTicks
      ]
      ++
      [ printf "<text x=\"%.1f\" y=\"%.1f\" font-family=\"sans-serif\" font-size=\"11\" text-anchor=\"middle\">%s</text>"
          (marginLeft + plotWidth / 2) (height - 4 :: Double) ("elapsed seconds" :: String)
      ]

    messageMarker (sec, text) =
      let x = xScale (fromIntegral sec)
          topY = marginTop
          bottomY = marginTop + plotHeight
          labelY = bottomY + 15
      in [ printf "<line x1=\"%.1f\" y1=\"%.1f\" x2=\"%.1f\" y2=\"%.1f\" stroke=\"red\" stroke-width=\"0.8\" stroke-dasharray=\"4,3\"/>"
             x topY x bottomY
         , printf "<text x=\"%.1f\" y=\"%.1f\" font-family=\"sans-serif\" font-size=\"10\" fill=\"red\" text-anchor=\"end\" transform=\"rotate(-90 %.1f %.1f)\">%s</text>"
             x labelY x labelY (escapeXml text)
         ]

escapeXml :: String -> String
escapeXml = concatMap esc
  where
    esc '<' = "&lt;"
    esc '>' = "&gt;"
    esc '&' = "&amp;"
    esc '"' = "&quot;"
    esc c   = [c]

main :: IO ()
main = do
  args <- getArgs
  case args of
    (logPath : rest) -> do
      let outPath = case rest of
            (o : _) -> o
            []      -> "rssi_timeline.svg"
      contents <- readFile logPath
      let samples = parseLog contents
          points = rssiPoints samples
          msgs = messages samples
      if null points
        then do
          hPutStrLn stderr "No RSSI readings found in log."
          exitFailure
        else do
          writeFile outPath (renderSvg points msgs)
          putStrLn ("Wrote " ++ outPath)
    _ -> do
      hPutStrLn stderr "Usage: rssi-timeline <path/to/info.log> [output.svg]"
      exitFailure
