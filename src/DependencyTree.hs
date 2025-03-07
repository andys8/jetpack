{-| Finds all dependencies of a module. It creates a try like the following for each module.
  ```
  (Dependency "./app/assets/modules/js/Super/foo_bar.js" Js <fullpath>)
  |
  +- (Dependency "Page/Super/FooBar/Main.elm" Elm <fullpath>)
  |
  `- (Dependency "Page/Super/FooBar/index.coffee" Coffee <fullpath>)
    |
    `- (Dependency "lodash" Js)
  ```


Finding modules
---------------

We are searching in the following folders.

1. relative to the file requiring the module
2. relative in node_modules
3. in `modules_directory`
4. in `source_directory`
5. in `{sourceDir}/../node_modules`
6. in `{root}/node_modules`
7. in `{root}/vendor/assets/components`
8. in `{root}/vendor/assets/javascripts`
9. woop woop! module not found

In each directory we search for the following names.
`{name}`  is the string from the `require` statement

1. `{folder}/{name}` from `browser` field in `package.json`
2. `{folder}/{name}` from `main` field in `package.json`
3. `{folder}/{name}`
4. `{folder}/{name}.js`
5. `{folder}/{name}/index.js`
6. `{folder}/{name}/{name}`
7. `{folder}/{name}/{name}.js`
8. `{folder}/{name}`
9. `{folder}/{name}.coffee`
10. `{folder}/{name}/index.coffee`

-}
module DependencyTree
  ( build
  , readTreeCache
  , writeTreeCache
  ) where

import Config (Config)
import qualified Config
import Control.Monad ((<=<))
import Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as BL
import Data.Maybe as M
import qualified Data.Text as T
import Data.Time.Clock ()
import Data.Time.Clock.POSIX
import qualified Data.Tree as Tree
import Dependencies
import qualified Parser.Ast as Ast
import qualified Parser.Require
import qualified Resolver
import Safe
import qualified Safe.IO
import System.FilePath ((<.>), (</>), takeDirectory)
import System.Posix.Files
import Utils.Tree (searchNode)

{-| Find all dependencies for the given entry points
-}
build :: Config -> Dependencies -> FilePath -> IO DependencyTree
build config cache entryPoint = do
  dep <- toDependency (Config.entryPoints config) entryPoint
  tree <- buildTree config cache dep
  return tree

buildTree :: Config -> Dependencies -> Dependency -> IO DependencyTree
buildTree config cache =
  Tree.unfoldTreeM
    (resolveChildren config <=< findRequires cache (Config.noParse config)) <=<
  Resolver.resolve config Nothing

readTreeCache :: Config.TempDir -> IO Dependencies
readTreeCache tempDir =
  (fromMaybe [] . Aeson.decode) <$>
  BL.readFile (Config.unTempDir tempDir </> "deps" <.> "json")

writeTreeCache :: Config.TempDir -> Dependencies -> IO ()
writeTreeCache tempDir =
  Safe.IO.writeFileByteString (Config.unTempDir tempDir </> "deps" <.> "json") .
  Aeson.encode

toDependency :: Config.EntryPoints -> FilePath -> IO Dependency
toDependency entryPoints path = do
  status <- getFileStatus $ Config.unEntryPoints entryPoints </> path
  let lastModificationTime =
        posixSecondsToUTCTime $ modificationTimeHiRes status
  return $ Dependency Ast.Js path path $ Just lastModificationTime

requireToDep :: FilePath -> Ast.Require -> Dependency
requireToDep path (Ast.Require t n) = Dependency t n path Nothing

findRequires ::
     Dependencies
  -> [Config.NoParse]
  -> Dependency
  -> IO (Dependency, [Dependency])
findRequires cache noParse parent@Dependency {filePath, fileType} =
  if Config.NoParse filePath `elem` noParse
    then return (parent, [])
    else case fileType of
           Ast.Js -> parseModule cache parent Parser.Require.jsRequires
           Ast.Coffee -> parseModule cache parent Parser.Require.coffeeRequires
           Ast.Elm -> return (parent, [])

findInCache :: Dependency -> Dependencies -> Maybe (Dependency, [Dependency])
findInCache dep = headMay . M.catMaybes . fmap (findInCache_ dep)

findInCache_ :: Dependency -> DependencyTree -> Maybe (Dependency, [Dependency])
findInCache_ dep = fmap toTuple . searchNode ((==) dep . Tree.rootLabel)
  where
    toTuple Tree.Node {Tree.rootLabel, Tree.subForest} =
      (rootLabel, fmap Tree.rootLabel subForest)

parseModule ::
     Dependencies
  -> Dependency
  -> (T.Text -> [Ast.Require])
  -> IO (Dependency, [Dependency])
parseModule cache dep@Dependency {filePath} parser =
  case findInCache dep cache of
    Just cached -> return cached
    Nothing -> do
      content <- readFile filePath
      let requires = parser $ T.pack content
      let dependencies = fmap (requireToDep $ takeDirectory filePath) requires
      return (dep, dependencies)

resolveChildren ::
     Config -> (Dependency, [Dependency]) -> IO (Dependency, [Dependency])
resolveChildren config (parent, children) = do
  resolved <- traverse (Resolver.resolve config (Just parent)) children
  return (parent, resolved)
