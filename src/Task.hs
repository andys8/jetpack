{-# LANGUAGE NamedFieldPuns #-}
module Task
  ( Env(..)
  , Task
  , ExceptIO
  , toTask
  , runTask
  ) where

import Control.Monad.Except
import Control.Monad.State
import Error
import qualified System.Console.AsciiProgress as Progress

type ExceptIO = ExceptT [Error] IO
type Task = StateT Env ExceptIO

data Env = Env
  { progressBar :: Maybe Progress.ProgressBar }


toTask :: IO a -> Task a
toTask = lift . lift

runTask :: Monad m => StateT Env (ExceptT e m) a -> m (Either e a)
runTask t = runExceptT $ evalStateT t $ Env { progressBar = Nothing }
