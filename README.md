# ChatLLaMbda

A small natural-language interface in Haskell, written for the CSE301
project ([assignment](https://noamz.org/teaching/CSE301/2026/Project/README.html)).
It decides whether an English sentence is grammatical using Lambek's
calculus of syntactic types, reads every derivation back as a lambda term,
and interprets each term as Python code against a database of facts.

```
$ ./ChatLLaMbda
Lexicon file: animals.elx
Facts about the world: aniworld.py
Starting chat...
> every grey cat sleeps
True
> every cat fears a dog
That sentence is ambiguous
Sense [Every_1 Cat_2 (\a. A_4 Dog_5 (\b. Fears_3 a b))]: True
Sense [A_4 Dog_5 (\a. Every_1 Cat_2 (\b. Fears_3 b a))]: False
> Seamus is hungry and
That is not a well-formed sentence
```

## Building and running

Requires GHC (tested with 9.6.7) and `python3`.

```
ghc ChatLLaMbda          # on Arch-based systems: ghc -dynamic ChatLLaMbda
./ChatLLaMbda
```

## Tests

```
./test.sh                # on systems without dynamic libraries: GHCFLAGS= ./test.sh
```

`test.sh` builds everything and runs two kinds of tests:

- `Tests.hs`: unit tests for `Lambek.hs`, covering grammatical and
  ungrammatical sentences (step 1), the exact derivations from the
  assignment's step 2 transcript, agreement between steps 1 and 2, and a few
  sequents on bare atoms.
- An end-to-end test that feeds `tests/chat.in` to the chat loop and compares
  its output with `tests/chat.out`, the assignment's sample transcript.

## Files

```
.
├── Lambek.hs          decision procedure, derivations as lambda terms
├── ChatLLaMbda.hs     read-eval-print loop, translation to Python
├── LTypes.hs          Lambek types and lexicons
├── LExp.hs            lambda terms
├── Parser.hs          lexicon parser
├── PySupport.hs       Python bridge
├── animals.elx        sample lexicon
├── aniworld.py        sample facts
├── Tests.hs           unit tests
├── test.sh            builds and runs all tests
└── tests/
    ├── chat.in        sample session input
    └── chat.out       expected transcript
```

## Design

**Step 1: deciding grammaticality.** `dec_rinv` and `dec_lfoc` follow the
focused sequent calculus of the assignment rule by rule. `dec_rinv` applies R /
R′ while the goal is a division, then tries each type of the context as the
focus (F). `dec_lfoc` dispatches on the focused type: an atom must match the
goal with empty sides (X); `A \ B` and `B / A` try every split of the left or
right context for the argument (L / L′). Each recursive call removes a
connective, so the search terminates. `isGrammatical` tries every combination
of lexical entries via `mapM` in the list monad.

**Step 2: derivations as lambda terms.** `der_rinv` and `der_lfoc` have the
same recursion as their `dec_` counterparts, but return lists of terms instead
of booleans. A left-focused derivation denotes a hole applied to arguments, `□
e1 … en`, and is represented by its argument list `[e1, …, en]`: X gives `[]`,
L / L′ prepend the derived argument, and F fills the hole with the focused
variable (`foldl A (V x) args`). R / R′ abstract over a variable chosen by
`LExp.fresh`, giving `\a.`, `\b.`, …. Word *i* of the sentence becomes the free
variable `Word_i`.

**Step 3: interpretation.** `derivations` pairs each term with the semantic
values of the lexical entries it used. `toPython` translates the term into
Python syntax: `\x. t` becomes `(lambda x: t)` and `t u` becomes `t(u)`.
`withEnv` binds the word variables by abstracting over them and applying the
result to their semantic values, as in `(lambda Conor_1, Sleeps_2:
Sleeps_2(Conor_1))(('Conor'), (lambda x : x in sleep))`. Python does the
beta-reduction, and the result is read back with `runPythonCode`.

## Known limitations

- Sentences with several "and"s are reported as ambiguous even when the
  readings differ only by associativity.
- If a semantic value raises a Python error, the error goes to stderr while
  `runPythonCode` waits on stdout, so the chat loop hangs.
- Empty contexts are allowed in the premises of L / L′, so this is Lambek's
  calculus with empty antecedents (L\*), not the original L. For `animals.elx`
  this makes no difference, since none of its argument types is derivable from
  the empty context, but a lexicon containing e.g. `Very : (n/n)/(n/n)` would
  accept "every very cat sleeps". We discovered this in a post-mortem analysis
  with Claude Opus 5.5.

## Acknowledgements and use of AI

Used Claude Opus 5.5 by Anthropic to understand the assignment, to write a test
suite, to draft a README.md, and to do a post-mortem analysis of the project.
