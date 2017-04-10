{-# LANGUAGE DeriveFunctor     #-}
{-# LANGUAGE OverloadedStrings #-}

module Logger
  ( clearLog, appendLog
  ) where

import Control.Monad.Trans.Class (lift)
import Data.Text as T
import System.FilePath ((</>))
import Task

appendLog :: FilePath -> T.Text -> Task ()
appendLog logDir msg = lift $ appendFile (logDir </> "jetpack.log") $ T.unpack msg

clearLog :: FilePath -> Task ()
clearLog logDir = lift $ writeFile (logDir </> "jetpack.log") ""
