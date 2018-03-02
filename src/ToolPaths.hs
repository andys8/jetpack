{-| This is used to check if the necessary tools for jetpack exist.
-}
module ToolPaths
  ( find
  , ToolPaths(..)
  ) where

import Config (Config(..))
import Control.Monad ((<=<))
import Control.Monad.Except (throwError)
import Error (Error(BinNotFound))
import System.Directory (makeAbsolute)
import System.Exit
import System.FilePath (FilePath)
import System.Process (system)
import Task

data ToolPaths = ToolPaths
  { elmMake :: FilePath
  , coffee :: FilePath
  }

{-| Check if tool from config exists. It falls back to a globally installed bin.
-}
find :: Config -> Task ToolPaths
find Config {elm_make_path, coffee_path} =
  ToolPaths <$> (binExists <=< toAbsPathOrBin "elm-make") elm_make_path <*>
  (binExists <=< toAbsPathOrBin "coffee") coffee_path

toAbsPathOrBin :: String -> Maybe FilePath -> Task FilePath
toAbsPathOrBin _ (Just pathToBin) = lift $ makeAbsolute pathToBin
toAbsPathOrBin defaultBin Nothing = return defaultBin

binExists :: String -> Task String
binExists bin = do
  exitCode <- lift $ system ("which " ++ bin ++ " >/dev/null")
  case exitCode of
    ExitSuccess -> return bin
    ExitFailure _ -> throwError [BinNotFound bin]
