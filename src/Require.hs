{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Require
  ( requires
  , require
  , getFileType
  , Require(..)
  , SourceType(..)
  ) where

import qualified Data.Maybe as M
import qualified Data.Text as T

import System.FilePath ((<.>), splitExtension)
import qualified Text.Parsec as P
import qualified Utils.Parser as UP

data Require = Require
  { fileType :: SourceType
  , fileName :: FilePath
  } deriving (Eq)

instance Show Require where
  show (Require t n) = "(Require " ++ show n ++ " " ++ show t ++ ")"

data SourceType
  = Coffee
  | Js
  | Elm
  | Sass
  deriving (Show, Eq)

{-| imports for doctests
   >>> import qualified Data.Text as T
   >>> :set -XOverloadedStrings
-}
{-| returns all requires of a file
    >>> :{
    requires $
      T.unlines
      [ "var _ = require('lodash')"
      , "var Main = require('Foo.Bar.Main.elm')"
      , ""
      , "Main.embed(document.getElementById('host'), {})"
      , "function require(foo) {"
      , "  console.log('local require')"
      , "}"
      ]
    :}
    [(Require "lodash" Js),(Require "Foo.Bar.Main.elm" Elm)]
-}
requires :: T.Text -> [Require]
requires = M.mapMaybe require . T.lines

{-| Parses a require statement and returns the filename and the type base on the extensions.

    >>> require "require('lodash')"
    Just (Require "lodash" Js)

    >>> require "require('Main.elm')"
    Just (Require "Main.elm" Elm)

    >>> require "require('Main.elm';"
    Nothing
-}
require :: T.Text -> Maybe Require
require content =
  case extractRequire content of
    Right (path, ext) -> Just $ Require (getFileType ext) $ path <.> ext
    Left _ -> Nothing

{-| running the parser
-}
extractRequire :: T.Text -> Either P.ParseError (FilePath, String)
extractRequire str = P.parse requireParser "Error" str

requireParser :: P.Parsec T.Text u (FilePath, String)
requireParser = do
  _ <- ignoreTillRequire
  _ <- requireKeyword
  _ <- P.spaces
  content <- P.choice [requireBetweenParens, coffeeRequire]
  return $ splitExtension content

requireBetweenParens :: P.Parsec T.Text u String
requireBetweenParens = UP.betweenParens UP.stringContent

coffeeRequire :: P.Parsec T.Text u String
coffeeRequire = P.spaces *> UP.stringContent

requireKeyword :: P.Parsec T.Text u String
requireKeyword = P.string "require"

ignoreTillRequire :: P.Parsec T.Text u String
ignoreTillRequire = P.manyTill P.anyChar (P.lookAhead $ P.try requireKeyword)

getFileType :: String -> SourceType
getFileType ".coffee" = Coffee
getFileType ".elm" = Elm
getFileType ".sass" = Sass
getFileType ".js" = Js
getFileType _ = Js
