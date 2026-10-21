module Platform (Platform (MacOS, Linux, WindowsHost), platformFromOsString) where

data Platform = MacOS | Linux | WindowsHost deriving (Show, Eq)

platformFromOsString :: String -> Maybe Platform
platformFromOsString "darwin" = Just MacOS
platformFromOsString "linux" = Just Linux
platformFromOsString "mingw32" = Just WindowsHost
platformFromOsString _ = Nothing
