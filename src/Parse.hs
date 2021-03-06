{-# LANGUAGE FlexibleContexts #-}
module Parse
  ( stringToProgram,
    parsePlusExpr,
    parsePlus,
    parseMult,
    parseMult',
    parseApp,
    parseA,
    Program,
    parse,
    Expr(..),
    BinOp(..)
  ) where

import Text.ParserCombinators.Parsec

type Program = [Expr]

data Expr = EInt Int 
            | EBool Bool 
            | EBinOp BinOp Expr Expr
            | EIf Expr Expr Expr
            | ELet String Expr Expr
            | EFun String Expr
            | EApp Expr Expr
            | ELetRec String String Expr Expr
            | EVariable String
            deriving (Eq,Show)

data BinOp = Plus | Mult | Lt deriving (Eq,Show)

parseTest f = parse f "Test"

stringToProgram :: String -> Either ParseError Program
stringToProgram = parse parseProgram "Parse.hs"

parseProgram :: Parser Program
parseProgram = many1 parseSentence

parseSentence :: Parser Expr
parseSentence = do{ e<-parseExpr; spaces; string ";;"; spaces; return e}

parseExpr = do
  spaces
  e <- parseExpr'''
  spaces
  return e

parseExpr''' :: Parser Expr
parseExpr''' = try parseBool <|>
             try parseIf <|>
             try parseLet <|>
             try parseLetRec <|> 
             try parseFun <|>
             try parseLtExpr <|>
             try parseBinOp <|>
             try parseAppExpr <|>
             try parseVariable

reservedName = ["let","in","fun","if","then","else"]

parseVariable :: Parser Expr
parseVariable = do 
  s <- parseValiableName 
  if elem s reservedName 
  then fail "reservedName is used for variable name."
  else return (EVariable s) 

parseBinOp :: Parser Expr
parseBinOp = try parseLtExpr

parseLtExpr :: Parser Expr
parseLtExpr = try parseLtExpr' <|> try parsePlusExpr

parseLtExpr' = do
  e1 <- parsePlusExpr
  spaces
  char '<'
  spaces
  e2 <- parsePlusExpr
  return (EBinOp Lt e1 e2)

parsePlus = parse parsePlusExpr "Plus"

parsePlusExpr = try parsePlusExpr' <|> try parseMultExpr
parsePlusExpr' = do
  e1 <- parseMultExpr
  spaces
  char '+'
  spaces
  e2 <- parsePlusExpr
  return (EBinOp Plus e1 e2) 

parseMult = parse parseMultExpr "Mult"
parseMult' = parse parseMultExpr' "Mult"

parseMultExpr = try parseMultExpr' <|> try parseAppExpr
parseMultExpr' = do
  e1 <- parseAppExpr 
  spaces
  char '*'
  spaces
  e2 <- parseMultExpr
  return (EBinOp Mult e1 e2)

parseApp = parse parseAppExpr "App"

parseAppExpr = parseAppExpr' <|> try parseAExpr
parseAppExpr' = try (do { e1<-(try parseFun <|> parseVariable); many1 space; e2<-parseAppExpr; return (EApp e1 e2) })


parseA = parse parseAExpr "A"
parseAExpr = try parseInt <|>
             try parseBool <|>
             try (do { char '('; spaces; e<-parseExpr; spaces; char ')'; return e}) <|>
             parseVariable

parseBool :: Parser Expr
parseBool = (string "True" >> return (EBool True)) <|> (string "False" >> return (EBool False))

parseInt :: Parser Expr
parseInt = try (do { n<-many1 digit; return (EInt ((read n)::Int))})

parseIf :: Parser Expr
parseIf = do {string "if"; spaces; c <- parseExpr; spaces; string "then"; spaces; e1 <- parseExpr; 
             spaces; string "else"; spaces; e2 <- parseExpr; return (EIf c e1 e2)}

parseValiableName :: Parser String
parseValiableName = (:) <$> lower <*> (many alphaNum)

parseKeyword :: String -> Parser String
parseKeyword k = do{ spaces; string k; spaces; return k}

pLet :: Parser String
pLet = parseKeyword "let"

pRec :: Parser String
pRec = parseKeyword "rec"

pFun :: Parser String
pFun = parseKeyword "fun"

pEqual :: Parser String
pEqual = parseKeyword "="

pArrow :: Parser String
pArrow = parseKeyword "->"

pIn :: Parser String
pIn = parseKeyword "in"

parseLet :: Parser Expr
parseLet = do
  pLet
  x <- parseValiableName
  pEqual
  e1 <- parseExpr
  pIn
  e2 <- parseExpr
  return (ELet x e1 e2)

parseLetRec :: Parser Expr
parseLetRec = do
  pLet
  pRec
  x <- parseValiableName
  pEqual
  pFun
  y <- parseValiableName
  pArrow
  e1 <- parseExpr
  pIn
  e2 <- parseExpr
  return (ELetRec x y e1 e2)

parseFun :: Parser Expr
parseFun = do
  pFun
  x <- parseValiableName
  pArrow
  e <- parseExpr
  return (EFun x e)
