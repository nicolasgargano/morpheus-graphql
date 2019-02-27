{-# LANGUAGE OverloadedStrings #-}

module Data.Morpheus.Parser.Query
    ( query
    )
where

import           Data.Text                      ( Text(..)
                                                , pack
                                                , unpack
                                                )
import           Data.Map                       ( fromList )
import           Data.Attoparsec.Text           ( Parser
                                                , char
                                                , letter
                                                , sepBy
                                                , skipSpace
                                                , try
                                                , parseOnly
                                                , parse
                                                , IResult(Done)
                                                , string
                                                , endOfInput
                                                )
import           Control.Applicative            ( (<|>)
                                                , many
                                                , some
                                                )
import           Data.Morpheus.Types.Types     ( Arguments
                                                , Argument(..)
                                                )
import           Data.Morpheus.Parser.Arguments
                                                ( arguments )
import           Data.Morpheus.Types.Error     ( GQLError )
import           Data.Data                      ( Data )
import           Data.Morpheus.ErrorMessage    ( syntaxError
                                                , semanticError
                                                )
import           Data.Morpheus.Parser.Primitive
                                                ( token
                                                , variable
                                                )

queryVariable :: Parser (Text, Argument)
queryVariable = do
    skipSpace
    variableName <- variable
    skipSpace
    char ':'
    skipSpace
    variableType <- token
    pure (variableName, Variable variableType)

queryArguments :: Parser Arguments
queryArguments = do
    skipSpace
    char '('
    skipSpace
    parameters <- queryVariable `sepBy` (skipSpace *> char ',')
    skipSpace
    char ')'
    pure parameters

query :: Parser  (Text,Arguments)
query = do
    string "query "
    skipSpace
    queryName <- token
    variables <- try (skipSpace *> queryArguments) <|> pure []
    pure (queryName, variables)

