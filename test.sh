#!/bin/sh
# Builds the project, runs the unit tests (Tests.hs), then runs an
# end-to-end test of the chat loop: feeds tests/chat.in to ChatLLaMbda and
# compares its output with tests/chat.out (the README's sample transcript,
# with words numbered from 1).
#
# GHCFLAGS defaults to -dynamic, which distributions such as Arch need;
# override it with e.g.  GHCFLAGS= ./test.sh
set -e
cd "$(dirname "$0")"
GHCFLAGS="${GHCFLAGS--dynamic}"

ghc $GHCFLAGS -outputdir build -v0 ChatLLaMbda.hs
ghc $GHCFLAGS -outputdir build -v0 Tests.hs
./Tests

# the chat loop exits with an error at end of input, so ignore its status
./ChatLLaMbda < tests/chat.in > build/chat.out 2>/dev/null || true
if diff -u tests/chat.out build/chat.out; then
  echo "end-to-end test passed"
else
  echo "FAIL: end-to-end test"
  exit 1
fi
