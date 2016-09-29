#!/bin/bash
set -eu
. osht.sh

SKIP true # we dont need no stinking tests

PLAN 1

OSHT_JUNIT=1
_OSHT_TESTING=1
_OSHT_JUNIT=$OSHT_STDIO

RUNS false
