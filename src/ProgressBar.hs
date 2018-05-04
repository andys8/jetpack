{-| ProgressBar displayes a small progressbar. Running tasks can call `step` to tick the bar one step further.
-}
module ProgressBar
  ( start
  , AP.complete
  , AP.ProgressBar
  , AP.tick
  ) where

import qualified Data.Text as T
import System.Console.AsciiProgress as AP

start :: Int -> T.Text -> IO AP.ProgressBar
start total title =
  AP.newProgressBar
    def
    { pgTotal = toInteger total
    , pgOnCompletion =
        Just (T.unpack title ++ " finished after :elapsed seconds")
    , pgCompletedChar = '█'
    , pgPendingChar = '░'
    , pgFormat = T.unpack title ++ " ╢:bar╟ :current/:total"
    }
