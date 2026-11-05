{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

module Lambek where

import Data.List (inits, tails)

import LTypes

-- Step 1: Checking grammaticality.

-- All ways of cutting a list into a prefix and a suffix.
splits :: [a] -> [([a],[a])]
splits xs = zip (inits xs) (tails xs)

dec_rinv :: [LTp] -> LTp -> Bool
dec_rinv gamma (DivL a b) = dec_rinv (a : gamma) b          -- R : A, G --> B  /  G --> A \ B
dec_rinv gamma (DivR b a) = dec_rinv (gamma ++ [a]) b       -- R': G, A --> B  /  G --> B / A
dec_rinv gamma (Atm p)    =                                 -- F
  or [dec_lfoc gl a gr p | (gl, a : gr) <- splits gamma]

dec_lfoc :: [LTp] -> LTp -> [LTp] -> Atm -> Bool
dec_lfoc gl (Atm q) gr p = null gl && null gr && q == p     -- X
dec_lfoc gl (DivL a b) gr p =                               -- L : argument taken from the left
  or [dec_rinv gl2 a && dec_lfoc gl1 b gr p | (gl1, gl2) <- splits gl]
dec_lfoc gl (DivR b a) gr p =                               -- L': argument taken from the right
  or [dec_rinv gr1 a && dec_lfoc gl b gr2 p | (gr1, gr2) <- splits gr]

-- A sentence is grammatical if some choice of lexical entries for its words
-- yields a provable sequent.
isGrammatical :: Lexicon sem -> [String] -> Bool
isGrammatical lex ws = any (\ts -> dec_rinv ts (stp lex)) (mapM typesOf ws)
  where
    typesOf w = [t | (w', t, _) <- items lex, w' == w]
