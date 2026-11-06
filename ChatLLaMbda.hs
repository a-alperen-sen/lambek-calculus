import Data.Char
import Data.List (intercalate)
import System.IO
import Control.Exception

import LTypes
import qualified Lambek
import LExp

import Parser
import PySupport

-- "standardize" the capitalization of a word by making the first
-- letter uppercase and the following letters lowercase.
-- (This will make it easier to look up words in the lexicon.)
stdize (c:cs) = toUpper c : map toLower cs

-- read-eval-print-loop
repl :: Lexicon PythonCode -> PythonHandle -> IO ()
repl elx phandle = do
  -- print the prompt
  putStr "> "
  -- get a line of input
  line <- getLine
  -- split it up into "standardized" words
  let ws = map stdize $ words line
  -- compute all derivations of the sentence and evaluate each one in Python
  case Lambek.derivations elx ws of
    []         -> putStrLn "That is not a well-formed sentence"
    [(t, env)] -> interpret t env >>= putStrLn
    ders       -> do
      putStrLn "That sentence is ambiguous"
      mapM_ (\(t, env) -> do
               r <- interpret t env
               putStrLn ("Sense [" ++ prettyLExp t ++ "]: " ++ r)) ders
  -- repeat
  repl elx phandle
  where
    interpret t env = runPythonCode phandle (PCode (withEnv env t))

-- translate a lambda term into a Python expression
toPython :: LExp -> String
toPython (V x)   = x
toPython (A t u) = toPython t ++ "(" ++ toPython u ++ ")"
toPython (L x t) = "(lambda " ++ x ++ ": " ++ toPython t ++ ")"

-- bind the word variables of a term to their semantic values by abstracting
-- over them and applying the result to the values
withEnv :: [(Var, PythonCode)] -> LExp -> String
withEnv env t = "(lambda " ++ intercalate ", " (map fst env) ++ ": " ++ toPython t ++ ")("
                ++ intercalate ", " ["(" ++ text c ++ ")" | (_, c) <- env] ++ ")"

main = do
  -- send console output immediately to the user
  hSetBuffering stdout NoBuffering
  -- input a lexicon file
  elx <- getLex
  -- input a database of facts
  db <- getDB
  -- launch a Python interpreter
  phandle <- launchPython db
  -- start the read-eval-print loop
  putStrLn "Starting chat..."
  repl elx phandle
  where
    getDB :: IO PythonCode
    getDB = do
      putStr "Facts about the world: "
      dname <- getLine
      mdb <- try (readFile dname) :: IO (Either IOError String)
      case mdb of
        Left err -> putStrLn ("Error loading file " ++ show err) >> getDB
        Right db -> return (PCode db)

    getLex :: IO (Lexicon PythonCode)
    getLex = do
      putStr "Lexicon file: "
      lname <- getLine
      res <- parseFile lexicon lname
      case res of
        Left err -> putStrLn ("Error loading file " ++ show err) >> getLex
        Right (Left err) -> putStrLn ("parse error at " ++ lname ++ ":" ++ show err) >> getLex
        Right (Right lex) -> return lex
