{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

module Lambek where

import Data.List (inits, tails)

import LTypes
import LExp

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

-- Step 2: the same search, but each rule builds a lambda term.

-- A left-focused derivation denotes a hole applied to arguments, represented
-- by its argument list.

der_rinv :: [(Var,LTp)] -> LTp -> [LExp]
der_rinv gamma (DivL a b) = [L x e | e <- der_rinv ((x,a) : gamma) b]       -- R
  where x = fresh (map (V . fst) gamma)
der_rinv gamma (DivR b a) = [L x e | e <- der_rinv (gamma ++ [(x,a)]) b]    -- R'
  where x = fresh (map (V . fst) gamma)
der_rinv gamma (Atm p) =                                                    -- F
  [foldl A (V x) args | (gl, (x,a) : gr) <- splits gamma, args <- der_lfoc gl a gr p]

der_lfoc :: [(Var,LTp)] -> LTp -> [(Var,LTp)] -> Atm -> [[LExp]]
der_lfoc gl (Atm q) gr p = [[] | null gl, null gr, q == p]                  -- X
der_lfoc gl (DivL a b) gr p =                                               -- L
  [e : args | (gl1, gl2) <- splits gl, e <- der_rinv gl2 a, args <- der_lfoc gl1 b gr p]
der_lfoc gl (DivR b a) gr p =                                               -- L'
  [e : args | (gr1, gr2) <- splits gr, e <- der_rinv gr1 a, args <- der_lfoc gl b gr2 p]

-- All derivations of a sentence; word i becomes the free variable Word_i. Each
-- derivation comes with the semantic values of its free variables, taken from
-- the lexical entries it used.
derivations :: Lexicon sem -> [String] -> [(LExp, [(Var,sem)])]
derivations lex ws =
  [ (t, [(x, v) | (x, _, v) <- choice])
  | choice <- mapM entriesOf (zip [1 :: Int ..] ws)
  , t <- der_rinv [(x, tp) | (x, tp, _) <- choice] (stp lex) ]
  where
    entriesOf (i, w) = [(w ++ "_" ++ show i, tp, v) | (w', tp, v) <- items lex, w' == w]
