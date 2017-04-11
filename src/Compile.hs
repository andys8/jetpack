{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE OverloadedStrings     #-}

{-|
-}
module Compile where

import Config (Config (..))
import Control.Monad.Except (throwError)
import Data.List as L
import Data.Text as T
import Data.Time.Clock
import Dependencies (Dependency (..))
import GHC.IO.Handle
import Parser.Ast as Ast
import System.Console.AsciiProgress
import System.Directory (copyFile)
import System.Exit
import System.FilePath ((</>))
import System.Process
import Task (Task, toTask)
import ToolPaths
import Utils.Files (pathToFileName)

newtype Compiler = Compiler { runCompiler :: FilePath -> FilePath -> Task [T.Text] }

compile :: ProgressBar -> Config -> ToolPaths ->  Dependency -> Task T.Text
compile pg config toolPaths Dependency {fileType, filePath} = do
  let (c, outputType) = compiler fileType config toolPaths pg
  let outputPath = buildArtifactPath config outputType filePath
  log <- (runCompiler c) filePath outputPath
  return $ T.unlines log

compiler :: Ast.SourceType -> Config -> ToolPaths -> ProgressBar -> (Compiler, String)
compiler fileType config ToolPaths{elmMake, sassc, coffee} pg =
  case fileType of
    Ast.Elm    -> (elmCompiler pg config elmMake, "js")
    Ast.Js     -> (jsCompiler pg, "js")
    Ast.Coffee -> (coffeeCompiler pg coffee, "js")
    Ast.Sass   -> (sassCompiler pg config sassc, "css")

buildArtifactPath :: Config -> String -> FilePath -> String
buildArtifactPath Config{temp_directory} extension inputPath =
  temp_directory </> pathToFileName inputPath extension

---------------
-- COMPILERS --
---------------

elmCompiler :: ProgressBar -> Config -> FilePath -> Compiler
elmCompiler pg Config{elm_root_directory} elmMake = Compiler $ \input output -> do
  -- TODO use elm_root_directory instead of the "../" below
  -- also pass in absolute paths
  let cmd = elmMake ++ " " ++ "../" ++ input ++ " --output " ++ "../" ++ output
  runCmd pg cmd $ Just elm_root_directory

coffeeCompiler :: ProgressBar -> FilePath -> Compiler
coffeeCompiler pg coffee = Compiler $ \input output -> do
  let cmd = coffee ++ " -p " ++ input ++ " > " ++ output
  runCmd pg cmd Nothing

{-| The js compiler will basically only copy the file into the tmp dir.
-}
jsCompiler :: ProgressBar -> Compiler
jsCompiler pg = Compiler $ \input output -> toTask $ do
  copyFile input output
  tick pg
  currentTime <- getCurrentTime
  let commandFinished = T.pack $ show currentTime
  return [commandFinished, T.concat ["moved ", T.pack input, " => ", T.pack output]]

sassCompiler :: ProgressBar -> Config -> FilePath -> Compiler
sassCompiler pg Config {sass_load_paths} sassc = Compiler $ \input output -> do
  let loadPath = L.intercalate ":" sass_load_paths
  let cmd = "SASS_PATH=" ++ loadPath ++ " " ++ sassc ++ " " ++ input ++ " " ++ output
  runCmd pg cmd Nothing

runCmd :: ProgressBar -> String -> Maybe String -> Task [T.Text]
runCmd pg cmd maybeCwd = do
  -- TODO: handle exit status here
  (_, Just out, _, ph) <- toTask $ createProcess (proc "bash" ["-c", cmd])
    { std_out = CreatePipe
    , cwd = maybeCwd
    }
  ec <- toTask $ waitForProcess ph
  case ec of
      ExitSuccess   -> toTask $ do
        content <- hGetContents out
        tick pg
        currentTime <- getCurrentTime
        let commandFinished = T.pack $ show currentTime
        return [commandFinished, T.pack cmd, T.pack content]
      ExitFailure _ -> throwError []
