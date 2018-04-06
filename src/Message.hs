module Message where

import qualified Data.Maybe as M
import Data.Semigroup ((<>))
import qualified Data.Text as T
import qualified Error
import Rainbow
       (Chunk, (&), brightRed, brightYellow, chunk, cyan, fore, green,
        putChunkLn, red, yellow)
import qualified System.Console.Terminal.Size as TermSize
import System.FilePath (FilePath)

termWidth :: IO Int
termWidth = max 20 <$> M.maybe 20 TermSize.width <$> TermSize.size

success :: IO ()
success = do
  width <- termWidth
  _ <- putChunkLn (separator width "*" & fore green)
  _ <- putChunkLn (message width "Compilation Succeeded" & fore green)
  putChunkLn (separator width "*" & fore green)

whichEntryPoints :: [FilePath] -> IO ()
whichEntryPoints entryPoints = do
  _ <-
    traverse (putChunkLn . fore cyan . chunk . (<>) ("- ") . T.pack) entryPoints
  _ <- putStrLn ""
  putStrLn ""

error :: [Error.Error] -> IO ()
error err = printError $ fmap (T.pack . Error.description) err

printError :: [T.Text] -> IO ()
printError err = do
  width <- termWidth
  _ <- putStrLn ""
  putChunkLn (separator width "~" & fore red)
  _ <- traverse (putChunkLn . fore brightRed . chunk) err
  _ <- putChunkLn (separator width "~" & fore red)
  _ <- traverse putChunkLn (errorMessage width)
  putChunkLn (separator width "~" & fore red)

warning :: [T.Text] -> IO ()
warning warnings = do
  _ <- traverse (putChunkLn . fore brightYellow . chunk) warnings
  warningHeader "Compilation Succeeded with Warnings"

warningHeader :: T.Text -> IO ()
warningHeader warnings = do
  width <- termWidth
  _ <- putChunkLn (separator width "*" & fore yellow)
  _ <- putChunkLn (message width warnings & fore yellow)
  putChunkLn (separator width "*" & fore yellow)

info :: T.Text -> IO ()
info = putStrLn . T.unpack

message :: Int -> T.Text -> Chunk T.Text
message width msg = chunk $ center width $ T.concat ["~*~ ", msg, " ~*~"]

separator :: Int -> T.Text -> Chunk T.Text
separator width c = chunk $ T.replicate width c

errorMessage :: Int -> [Chunk T.Text]
errorMessage width =
  (fore red . chunk . center width) <$> ["¡Compilation failed!", "¯\\_(ツ)_/¯"]

center :: Int -> T.Text -> T.Text
center width msg = T.append (T.replicate n " ") msg
  where
    textLength = T.length msg
    half = quot width 2
    halfText = quot textLength 2
    n = half - halfText
