{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( run
  ) where

import CliArguments (Args (..))
import Config ()
import Control.Monad.Except
import Control.Monad.Free (Free, foldFree)
import Data.Functor.Sum (Sum (..))
import Data.List as L
import Data.List.Utils (uniq)
import Data.Tree as Tree
import qualified Error
import qualified Interpreter.Logger as LogI
import qualified Interpreter.Pipeline as PipelineI
import qualified Logger
import Pipeline
import qualified System.Exit
import Task
import Utils.Free (toLeft, toRight)

run :: IO ()
run = do
  e <- runExceptT $ runProgram program
  case e of
    Left err -> do
      putStrLn "Compilation failed!"
      System.Exit.die $ L.unlines $ fmap Error.description err
    Right _ -> putStrLn "Compilation succeeded!"

program :: Pipeline ()
program = do
  args        <- readCliArgs
  config      <- readConfig (configPath args)
  toolPaths   <- setup config
  entryPoints <- findEntryPoints config args
  deps        <- dependencies config entryPoints
  let modules = uniq $ concatMap Tree.flatten deps
  _       <- compile config toolPaths modules
  modules <- concatModules config deps
  _       <- outputCreatedModules config modules
  return ()

runProgram :: Pipeline a -> Task a
runProgram = foldFree executor . foldFree interpreter

interpreter :: PipelineF a -> Free (Sum Logger.LogF Task) a
interpreter op =
  toLeft (LogI.interpreter op) *> toRight (lift $ PipelineI.interpreter op)

executor :: Sum Logger.LogF Task a -> Task a
executor (InL l@(Logger.Log _ _ next)) = lift $ Logger.executor l >> return next
executor (InR io) = io
