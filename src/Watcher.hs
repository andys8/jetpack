module Watcher where

import qualified Builder
import CliArguments (Args(..))
import Config
import Control.Concurrent
import Control.Monad.Except (throwError)
import Data.Foldable (traverse_)
import qualified Data.Text as T
import Error
import GHC.IO.Handle
import qualified Notify
import qualified System.Directory as Dir
import System.Environment
import System.Exit
import System.FilePath ()
import qualified System.Posix.IO as PIO
import System.Posix.Process
import System.Posix.Signals
import System.Posix.Types (ProcessID)
import System.Process

watch :: Config.Config -> Args -> IO ()
watch config args = do
  putStrLn "Watching. Hit `ctrl-c` to exit."
  Notify.watch
    (T.pack $ Config.source_directory config)
    [".elm", ".coffee", ".js", ".sass", ".scss", ".json"]
    (Builder.build config args)
