module Config
  ( Config(..)
  , readConfig
  , load
  , ElmPath(ElmPath)
  , unElmPath
  , CoffeePath(CoffeePath)
  , unCoffeePath
  , EntryPoints(EntryPoints)
  , unEntryPoints
  , ModulesDir(ModulesDir)
  , unModulesDir
  , SourceDir(SourceDir)
  , unSourceDir
  , ElmRoot(ElmRoot)
  , unElmRoot
  , TempDir(TempDir)
  , unTempDir
  , LogDir(LogDir)
  , unLogDir
  , OutputDir(OutputDir)
  , unOutputDir
  , NoParse(NoParse)
  , unNoParse
  , WatchFileExt(WatchFileExt)
  , unWatchFileExt
  , WatchIgnorePatterns(WatchIgnorePatterns)
  , unWatchIgnorePatterns
  , HotReloadingPort(HotReloadingPort)
  , unHotReloadingPort
  ) where

import qualified Data.Aeson as Aeson
import Data.Aeson ((.!=), (.:), (.:?))
import Data.Aeson.Types (typeMismatch)
import qualified Data.ByteString.Lazy as BL
import Data.Semigroup ((<>))
import qualified Data.Text as T
import Message
import qualified System.Directory as Dir
import System.Exit
import System.FilePath ((</>))

data Config = Config
  { entryPoints :: EntryPoints
  , modulesDirs :: [ModulesDir]
  , sourceDir :: SourceDir
  , elmRoot :: ElmRoot
  , tempDir :: TempDir
  , logDir :: LogDir
  , outputDir :: OutputDir
  , elmPath :: Maybe ElmPath
  , coffeePath :: Maybe CoffeePath
  , noParse :: [NoParse]
  , watchFileExt :: [WatchFileExt]
  , watchIgnorePatterns :: [WatchIgnorePatterns]
  , hotReloadingPort :: HotReloadingPort
  } deriving (Show, Eq)

newtype ElmPath = ElmPath
  { unElmPath :: FilePath
  } deriving (Show, Eq)

newtype CoffeePath = CoffeePath
  { unCoffeePath :: FilePath
  } deriving (Show, Eq)

newtype EntryPoints = EntryPoints
  { unEntryPoints :: FilePath
  } deriving (Show, Eq)

newtype ModulesDir = ModulesDir
  { unModulesDir :: FilePath
  } deriving (Show, Eq)

newtype SourceDir = SourceDir
  { unSourceDir :: FilePath
  } deriving (Show, Eq)

newtype ElmRoot = ElmRoot
  { unElmRoot :: FilePath
  } deriving (Show, Eq)

newtype TempDir = TempDir
  { unTempDir :: FilePath
  } deriving (Show, Eq)

newtype LogDir = LogDir
  { unLogDir :: FilePath
  } deriving (Show, Eq)

newtype OutputDir = OutputDir
  { unOutputDir :: FilePath
  } deriving (Show, Eq)

newtype NoParse = NoParse
  { unNoParse :: FilePath
  } deriving (Show, Eq)

newtype WatchFileExt = WatchFileExt
  { unWatchFileExt :: T.Text
  } deriving (Show, Eq)

newtype WatchIgnorePatterns = WatchIgnorePatterns
  { unWatchIgnorePatterns :: T.Text
  } deriving (Show, Eq)

newtype HotReloadingPort = HotReloadingPort
  { unHotReloadingPort :: Int
  } deriving (Show, Eq)

instance Aeson.FromJSON Config where
  parseJSON (Aeson.Object v) =
    Config --
     <$>
    (EntryPoints <$> v .: "entry_points") <*>
    (fmap ModulesDir <$> v .: "modules_directories") <*>
    (SourceDir <$> v .: "source_directory") <*>
    (ElmRoot <$> v .: "elm_root_directory") <*>
    (TempDir <$> v .: "temp_directory" .!= "./.jetpack/build_artifacts") <*>
    (LogDir <$> v .:? "log_directory" .!= "./.jetpack/logs") <*>
    (OutputDir <$> v .: "output_js_directory") <*>
    (fmap ElmPath <$> v .:? "elm_bin_path") <*>
    (fmap CoffeePath <$> v .:? "coffee_path") <*>
    (fmap NoParse <$> v .:? "no_parse" .!= []) <*>
    (fmap WatchFileExt <$>
     v .:? "watch_file_extensions" .!= [".elm", ".coffee", ".js", ".json"]) <*>
    (fmap WatchIgnorePatterns <$>
     v .:? "watch_file_ignore_patterns" .!= ["/[.]#[^/]*$", "/~[^/]*$"]) <*>
    (HotReloadingPort <$> v .:? "hot_reloading_port" .!= 31337)
  parseJSON invalid = typeMismatch "Config" invalid

readConfig :: IO Config
readConfig = do
  cwd <- Dir.getCurrentDirectory
  load cwd

{-| Loads configuration for jetpack from `jetpack.json`.
-}
load :: FilePath -> IO (Config)
load root = do
  let path = root </> "jetpack.json"
  exists <- Dir.doesFileExist path
  if exists
    then do
      content <- BL.readFile path
      case Aeson.eitherDecode content of
        Right config -> return config
        Left err -> do
          _ <-
            Message.error $
            T.unlines
              [ "Invalid jetpack.json: " <> T.pack path
              , ""
              , "    " <> T.pack err
              , ""
              ]
          System.Exit.exitFailure
    else do
      _ <-
        Message.error $
        T.unlines ["I didn't find a config for jetpack at " <> T.pack path]
      System.Exit.exitFailure
