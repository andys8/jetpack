module Logger
  ( clearLog
  , appendLog
  , compileLog
  , compileTime
  , preHookLog
  , postHookLog
  , allLogs
  ) where

import Config
import Data.Text as T
import System.FilePath ((</>))
import Task

compileLog, compileTime, preHookLog, postHookLog :: T.Text
compileLog = "compile.log"

compileTime = "compile.time"

preHookLog = "pre-hook.log"

postHookLog = "post-hook.log"

allLogs :: [T.Text]
allLogs = [compileTime, compileLog, preHookLog, postHookLog]

appendLog :: Config -> T.Text -> T.Text -> Task ()
appendLog config fileName msg = do
  let Config {logDir} = config
  lift $ appendFile (logDir </> T.unpack fileName) $ T.unpack msg

clearLog :: Config -> T.Text -> Task ()
clearLog config fileName = do
  let Config {logDir} = config
  lift $ writeFile (logDir </> T.unpack fileName) ""
