{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
module ProgressBar
  ( step
  , start
  , end
  ) where

import Control.Monad.State (get, modify)
import qualified Data.Text as T
import System.Console.AsciiProgress as AP
import Task (Env (..), Task, toTask)

step :: Task ()
step = do
  Env {progressBar} <- get
  case progressBar of
    Just pg -> toTask $ AP.tick pg
    Nothing -> return ()

start :: Int -> T.Text -> Task ()
start total title = do
  pg <- toTask $ AP.newProgressBar def
      { pgTotal = toInteger total
      , pgOnCompletion = Just (T.unpack title ++ " finished after :elapsed seconds")
      , pgCompletedChar = '█'
      , pgPendingChar = '░'
      , pgFormat = T.unpack title ++ " ╢:bar╟ :current/:total"
      }
  modify (\env -> env { progressBar = Just pg })
  return ()

end :: Task ()
end = do
  Env {progressBar} <- get
  case progressBar of
    Just pg -> toTask $ complete pg
    Nothing -> return ()
