module Sox (soxArgs) where

import Platform (Platform (Linux, MacOS, WindowsHost))

-- Builds the sox args that record the microphone and write WAV to stdout.
soxArgs :: Platform -> Maybe String -> [String]
soxArgs platform device =
    ["-V1"] ++ input ++ ["-t", "wav", "-"]
  where
    input = case device of
        Nothing -> ["-d"]
        Just name -> ["-t", soxDriver platform, name]
    soxDriver MacOS = "coreaudio"
    soxDriver Linux = "pulseaudio"
    soxDriver WindowsHost = "waveaudio"
