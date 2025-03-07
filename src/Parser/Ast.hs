module Parser.Ast
  ( Require(..)
  , SourceType(..)
  ) where

import Data.Aeson as Aeson
import GHC.Generics (Generic)
import System.FilePath ()

data Require =
  Require SourceType
          FilePath
  deriving (Eq)

instance Show Require where
  show (Require t n) = "(Require " ++ show n ++ " " ++ show t ++ ")"

data SourceType
  = Coffee
  | Js
  | Elm
  deriving (Show, Eq, Generic)

instance FromJSON SourceType

instance ToJSON SourceType
