-- Unit tests for Lambek.hs (steps 1 and 2), using the lexicon animals.elx.
-- Build and run with ./test.sh, which also runs an end-to-end test of step 3.

import Data.Char (toUpper, toLower)
import Control.Monad (unless)
import System.Exit (exitFailure)

import LTypes
import LExp
import Lambek
import Parser

-- same normalisation of words as in ChatLLaMbda.hs
sentence :: String -> [String]
sentence = map stdize . words
  where stdize (c:cs) = toUpper c : map toLower cs
        stdize []     = []

-- print a failure message, and return whether the test passed
check :: String -> Bool -> IO Bool
check name ok = do
  unless ok $ putStrLn ("FAIL: " ++ name)
  return ok

grammatical, ungrammatical :: [String]
grammatical =
  [ "Seamus is hungry and grey", "Conor sleeps", "every cat sleeps"
  , "every grey cat sleeps", "someone fears Fiona", "every cat fears a dog"
  , "Seamus sleeps and Seamus is grey" ]
ungrammatical =
  [ "Seamus is hungry and", "sleeps Conor", "Conor chases", "every cat fears"
  , "Conor Seamus", "Foo", "" ]

-- expected derivations (README, step 2), in the order they are found
derivationTests :: [(String, [String])]
derivationTests =
  [ ("Seamus is hungry and grey", ["Is_2 Seamus_1 (And_4 Hungry_3 Grey_5)"])
  , ("Conor sleeps",              ["Sleeps_2 Conor_1"])
  , ("every cat sleeps",          ["Every_1 Cat_2 (\\a. Sleeps_3 a)"])
  , ("every grey cat sleeps",     ["Every_1 (Grey_2 Cat_3) (\\a. Sleeps_4 a)"])
  , ("every cat fears a dog",     [ "Every_1 Cat_2 (\\a. A_4 Dog_5 (\\b. Fears_3 a b))"
                                  , "A_4 Dog_5 (\\a. Every_1 Cat_2 (\\b. Fears_3 b a))" ])
  , ("Seamus sleeps and Conor sleeps and Tara sleeps",
      [ "And_3 (Sleeps_2 Seamus_1) (And_6 (Sleeps_5 Conor_4) (Sleeps_8 Tara_7))"
      , "And_6 (And_3 (Sleeps_2 Seamus_1) (Sleeps_5 Conor_4)) (Sleeps_8 Tara_7)" ])
  , ("Seamus is hungry and",      [])
  ]

main :: IO ()
main = do
  res <- parseFile lexicon "animals.elx"
  lx <- case res of
    Right (Right lx) -> return lx
    _                -> putStrLn "FAIL: could not load animals.elx" >> exitFailure

  let terms s = map (prettyLExp . fst) (derivations lx (sentence s))
      allSentences = grammatical ++ ungrammatical ++ map fst derivationTests

  results <- sequence $
    -- step 1: grammaticality
    [ check ("grammatical: " ++ show s) (isGrammatical lx (sentence s)) | s <- grammatical ] ++
    [ check ("ungrammatical: " ++ show s) (not (isGrammatical lx (sentence s))) | s <- ungrammatical ] ++
    -- step 2: derivations as lambda terms
    [ check ("derivations of " ++ show s ++ ": got " ++ show (terms s)) (terms s == expected)
    | (s, expected) <- derivationTests ] ++
    -- steps 1 and 2 agree
    [ check ("dec/der agree on " ++ show s)
            (isGrammatical lx (sentence s) == not (null (terms s)))
    | s <- allSentences ] ++
    -- a few direct sequents
    [ check "p --> p"                 (dec_rinv [Atm "p"] (Atm "p"))
    , check "not (p --> q)"           (not (dec_rinv [Atm "p"] (Atm "q")))
    , check "not (--> p)"             (not (dec_rinv [] (Atm "p")))
    , check "p, p \\ q --> q"         (dec_rinv [Atm "p", DivL (Atm "p") (Atm "q")] (Atm "q"))
    , check "not (p \\ q, p --> q)"   (not (dec_rinv [DivL (Atm "p") (Atm "q"), Atm "p"] (Atm "q")))
    , check "q / p, p --> q"          (dec_rinv [DivR (Atm "q") (Atm "p"), Atm "p"] (Atm "q"))
    , check "type raising: p --> q / (p \\ q)"
            (dec_rinv [Atm "p"] (DivR (Atm "q") (DivL (Atm "p") (Atm "q"))))
    ]

  let failures = length (filter not results)
  putStrLn (show (length results - failures) ++ "/" ++ show (length results) ++ " unit tests passed")
  unless (failures == 0) exitFailure
