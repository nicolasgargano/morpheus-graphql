{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeOperators     #-}

module Data.Morpheus
  ( interpreter
  , eitherToResponse
  , GQLResponse
  , GQLSelection
  , GQLKind(description)
  , GQLQuery
  , GQLArgs
  , (::->)(..)
  , GQLRequest(..)
  , ResolveIO
  , GQLInput
  , EnumOf(unpackEnum)
  , GQLEnum
  , GQLRoot(..)
  , GQLMutation
  , NoMutation(..)
  ) where

import           Control.Monad.Trans.Except          (ExceptT (..), runExceptT)
import           Data.Aeson                          (decode)
import qualified Data.ByteString.Lazy.Char8          as B
import           Data.Morpheus.Error.Utils           (errorMessage, renderErrors)
import           Data.Morpheus.Kind.GQLArgs          (GQLArgs)
import           Data.Morpheus.Kind.GQLEnum          (GQLEnum)
import           Data.Morpheus.Kind.GQLInput         (GQLInput)
import           Data.Morpheus.Kind.GQLKind          (GQLKind (description))
import           Data.Morpheus.Kind.GQLMutation      (GQLMutation (..), NoMutation (..))
import           Data.Morpheus.Kind.GQLQuery         (GQLQuery (..))
import           Data.Morpheus.Kind.GQLSelection     (GQLSelection)
import           Data.Morpheus.Parser.Parser         (parseGQL, parseLineBreaks)
import           Data.Morpheus.PreProcess.PreProcess (preProcessQuery)
import           Data.Morpheus.Schema.Utils.Utils    (TypeLib)
import           Data.Morpheus.Types.Describer       ((::->) (Resolver), EnumOf (unpackEnum))
import           Data.Morpheus.Types.Error           (ResolveIO, failResolveIO)
import           Data.Morpheus.Types.JSType          (JSType)
import           Data.Morpheus.Types.Query.Operator  (Operator (..))
import           Data.Morpheus.Types.Request         (GQLRequest (..))
import           Data.Morpheus.Types.Response        (GQLResponse (..))
import           Data.Text                           (pack)

data GQLRoot a b = GQLRoot
  { queryResolver    :: a
  , mutationResolver :: b
  }

schema :: (GQLQuery a, GQLMutation b) => a -> b -> TypeLib
schema queryRes mutationRes = querySchema queryRes $ mutationSchema mutationRes

resolve :: (GQLQuery a, GQLMutation b) => GQLRoot a b -> GQLRequest -> ResolveIO JSType
resolve rootResolver body = do
  rootGQL <- ExceptT $ pure (parseGQL body >>= preProcessQuery gqlSchema)
  case rootGQL of
    Query _ _args selection _pos    -> encodeQuery queryRes gqlSchema selection
    Mutation _ _args selection _pos -> encodeMutation mutationRes selection
  where
    gqlSchema = schema queryRes mutationRes
    queryRes = queryResolver rootResolver
    mutationRes = mutationResolver rootResolver

lineBreaks :: B.ByteString -> [Int]
lineBreaks req =
  case decode req of
    Just x  -> parseLineBreaks x
    Nothing -> []

interpreter :: (GQLQuery a, GQLMutation b) => GQLRoot a b -> B.ByteString -> IO GQLResponse
interpreter rootResolver request = do
  value <- runExceptT $ parseRequest request >>= resolve rootResolver
  case value of
    Left x  -> pure $ Errors $ renderErrors (lineBreaks request) x
    Right x -> pure $ Data x

eitherToResponse :: (a -> b) -> Either String a -> ResolveIO b
eitherToResponse _ (Left x)  = failResolveIO $ errorMessage 0 (pack $ show x)
eitherToResponse f (Right x) = pure (f x)

parseRequest :: B.ByteString -> ResolveIO GQLRequest
parseRequest text =
  case decode text of
    Just x  -> pure x
    Nothing -> failResolveIO $ errorMessage 0 (pack $ show text)
