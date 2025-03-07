module ConcatModuleSpec where

import ConcatModule
import Config
import Control.Monad.State (modify)
import Data.Foldable
import Data.Text as T
import Data.Tree as Tree
import Dependencies as D
import Parser.Ast as Ast
import System.Directory (removeFile)
import System.FilePath ((<.>), (</>))
import Test.Tasty
import Test.Tasty.HUnit

mockModule :: T.Text
mockModule = T.unlines ["var foo = require('foo.js');", "", "foo(42)"]

wrappedModule :: T.Text
wrappedModule =
  T.unlines
    [ "/* START: testFunction */"
    , "function testFunction_js(module, exports) {"
    , "var foo = require('foo.js');"
    , ""
    , "foo(42)"
    , "\n} /* END: testFunction */"
    ]

mockDependencyTree :: D.DependencyTree
mockDependencyTree =
  Tree.Node
    (dependency "index")
    [Tree.Node (dependency "main") [], Tree.Node (dependency "index") []]
  where
    dependency fileName =
      D.Dependency
        Ast.Js
        (fileName <.> "js")
        ("ui" </> "src" </> fileName <.> "js")
        Nothing

mockConfig :: Config
mockConfig =
  Config
  { entryPoints =
      EntryPoints ("." </> "test" </> "fixtures" </> "concat" </> "modules")
  , modulesDirs = []
  , sourceDir =
      SourceDir ("." </> "test" </> "fixtures" </> "concat" </> "sources")
  , elmRoot = ElmRoot ("." </> "test" </> "fixtures" </> "concat" </> "sources")
  , tempDir = TempDir ("." </> "test" </> "fixtures" </> "concat" </> "tmp")
  , logDir = LogDir ("." </> "test" </> "fixtures" </> "concat" </> "logs")
  , outputDir = OutputDir ("." </> "test" </> "fixtures" </> "concat" </> "js")
  , elmPath = Nothing
  , coffeePath = Nothing
  , noParse = []
  , watchFileExt = []
  , watchIgnorePatterns = []
  }

mockDependency :: FilePath -> FilePath -> D.Dependency
mockDependency f p = D.Dependency Ast.Js f p Nothing

mockDependencies :: D.Dependencies
mockDependencies =
  [ Tree.Node
      (dependency "modules" "Foo")
      [Tree.Node (dependency "sources" "Moo") []]
  ]
  where
    dependency location fileName =
      mockDependency
        ("." </> fileName)
        ("." </> "test" </> "fixtures" </> "concat" </> location </> "Page" </>
         fileName <.>
         "js")

expectedOutput :: [T.Text]
expectedOutput =
  [ T.unlines $
    [ "(function() {"
    , "var jetpackCache = {};"
    , "function jetpackRequire(fn, fnName) {"
    , "  var e = {};"
    , "  var m = { exports : e };"
    , "  if (typeof fn !== \"function\") {"
    , "    console.error(\"Required function isn't a jetpack module.\", fn)"
    , "    return;"
    , "  }"
    , "  if (jetpackCache[fnName]) {"
    , "    return jetpackCache[fnName];"
    , "  }"
    , "  jetpackCache[fnName] = m.exports;"
    , "  fn(m, e);  "
    , "  jetpackCache[fnName] = m.exports;"
    , "  return m.exports;"
    , "}"
    , "/* START: ./test/fixtures/concat/modules/Page/Foo.js */"
    , "function test___fixtures___concat___modules___Page___Foo_js_js(module, exports) {"
    , "var moo = jetpackRequire(test___fixtures___concat___sources___Page___Moo_js_js, \"test___fixtures___concat___sources___Page___Moo_js_js\");"
    , "moo(4, 2);"
    , "\n} /* END: ./test/fixtures/concat/modules/Page/Foo.js */"
    , "/* START: ./test/fixtures/concat/sources/Page/Moo.js */"
    , "function test___fixtures___concat___sources___Page___Moo_js_js(module, exports) {"
    , "module.exports = function(a, b) {"
    , "  console.log(a + b + \"\");"
    , "};"
    , "\n} /* END: ./test/fixtures/concat/sources/Page/Moo.js */"
    , ""
    , "jetpackRequire(test___fixtures___concat___modules___Page___Foo_js_js, \"test___fixtures___concat___modules___Page___Foo_js_js\");"
    , "})();"
    ]
  ]

suite :: TestTree
suite =
  testGroup
    "ConcatModule"
    [ testCase "#wrapModule" $ do
        wrapModule "a___b.elm" "" @?=
          "/* START: a/b.elm */  console.warn(\"a/b.elm: is an empty module!\");\nfunction a___b_elm_js(module, exports) {\n\n} /* END: a/b.elm */\n"
    , testCase "#wrapModule wraps a module in a function" $
      wrapModule "testFunction" mockModule @?= wrappedModule
    , testCase
        "#replaceRequire replaces require('string') with jetpackRequire(function, fnName)" $
      replaceRequire
        (mockDependency "foo" $ "ui" </> "src" </> "foo")
        "var x = require('foo')" @?=
      "var x = jetpackRequire(ui___src___foo_js, \"ui___src___foo_js\")"
    , testCase
        "#replaceRequire replaces require(\"string\") with jetpackRequire(function, fnName)" $
      replaceRequire
        (mockDependency "foo" $ "ui" </> "src" </> "foo")
        "var x = require(\"foo\")" @?=
      "var x = jetpackRequire(ui___src___foo_js, \"ui___src___foo_js\")"
    , testCase
        "#replaceRequire replaces require( 'string' ) with jetpackRequire(function, fnName)" $
      replaceRequire
        (mockDependency "foo" $ "ui" </> "src" </> "foo")
        "var x = require( 'foo' )" @?=
      "var x = jetpackRequire(ui___src___foo_js, \"ui___src___foo_js\")"
    , testCase "#wrap" $ do
        (paths, actual) <- unzip <$> traverse (wrap mockConfig) mockDependencies
        paths @?= ["./test/fixtures/concat/js/Page/Foo.js"]
        actual @?= expectedOutput
    ]
