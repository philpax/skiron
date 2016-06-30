module Main where
import System.Environment 
import Control.Monad
import Control.Applicative ((<*))
import Text.Parsec
import Text.Parsec.String
import Text.Parsec.Expr
import Text.Parsec.Token
import Text.Parsec.Language

-- AST
data UnaryOp = Deref
    deriving Show

data BinaryOp = Add | Sub | Mul | Div | BinAnd | BinOr | BinXor | ShiftLeft | ShiftRight | Equality | LessThan | GreaterThan
    deriving Show

data Expr = Var String | UnaryExpr UnaryOp Expr | BinaryExpr BinaryOp Expr Expr
    deriving Show

data Stmt = Seq [Stmt] | AsgnStmt Expr Expr | IfStmt Expr Stmt Stmt | PassStmt
    deriving Show

-- Definition of language
def = emptyDef{ commentStart = "/*"
              , commentEnd = "*/"
              , identStart = letter
              , identLetter = alphaNum
              , opStart = oneOf "*+-/&|^<>="
              , opLetter = oneOf "*+-/&|^<>="
              , reservedOpNames = ["+", "-", "*", "/", "&", "|", "^", "<<", ">>", "==", "<", ">", "="]
              , reservedNames = ["if", "else"] 
              }

-- Destructured token parser, based off language
TokenParser{ parens = m_parens
           , braces = m_braces
           , identifier = m_identifier
           , reservedOp = m_reservedOp
           , reserved = m_reserved
           , semiSep1 = m_semiSep1
           , whiteSpace = m_whiteSpace } = makeTokenParser def

-- Expression parser from table
exprParser :: Parser Expr
exprParser = buildExpressionParser table termParser <?> "expression"
table = [ [prefix "*" (UnaryExpr Deref)]
        , [binaryl "*" (BinaryExpr Mul)]
        , [binaryl "/" (BinaryExpr Div)]
        , [binaryl "&" (BinaryExpr BinAnd)]
        , [binaryl "|" (BinaryExpr BinOr)]
        , [binaryl "^" (BinaryExpr BinXor)]
        , [binaryl "<<" (BinaryExpr ShiftLeft)]
        , [binaryl ">>" (BinaryExpr ShiftRight)]
        , [binaryl "==" (BinaryExpr Equality)]
        , [binaryl "<" (BinaryExpr LessThan)]
        , [binaryl ">" (BinaryExpr GreaterThan)]
        , [binaryl "+" (BinaryExpr Add)]
        , [binaryl "-" (BinaryExpr Sub)]
        ]

prefix op expr = Prefix (m_reservedOp op >> return expr)
binary op expr assoc = Infix (m_reservedOp op >> return expr) assoc
binaryl op expr = binary op expr AssocLeft

-- Var
varParser = fmap Var m_identifier

-- Term
termParser = m_parens exprParser <|> varParser

-- Assignment statement parser
asgnStmtParser = do
                    lhs <- varParser
                    m_reservedOp "="
                    rhs <- exprParser
                    return (AsgnStmt lhs rhs)

-- If statement parser
ifStmtParser =  do
                    m_reserved "if"
                    condExpr <- exprParser
                    thenStmt <- m_braces stmtParser
                    elseStmt <- option PassStmt (m_reserved "else" >> m_braces stmtParser)
                    return (IfStmt condExpr thenStmt elseStmt)

{-
ifStmtParser = IfStmt <$> exprParser
                      <*> m_braces stmtParser
                      <*> (option (ExprStmt Pass) (m_reserved "else" *> m_braces stmtParser))
-}
-- Statement parser
stmtParser :: Parser Stmt
stmtParser = fmap Seq (m_semiSep1 asgnStmtParser) <|> ifStmtParser

-- Main parser that swallows whitespace and terminates prior to EOF
mainParser :: Parser Stmt
mainParser = m_whiteSpace >> stmtParser <* eof

-- Parse string using mainParser
parseString s = parse mainParser "" s

-- Prints out parse tree for a given string
play :: String -> IO ()
play inp =  case parseString inp of
                Left err -> print err
                Right ans -> print ans

printParse s = do
                putStrLn "TEST: "
                putStrLn s
                putStrLn ""
                putStrLn "TREE: "
                play s
                putStrLn "--------------"

main :: IO ()
main =  do
            printParse "a = b"
            printParse "a = b; c = d"
            printParse "if a > b { a = c } else { a = d }"
            printParse "if a > b { a = c }"
            printParse "\
\                        if a > b {\n\
\                            a = b;\n\
\                            c = d\n\
\                        }"