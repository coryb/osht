#!/bin/bash
set -eu
. osht.sh

PLAN 32

# simple command output
IS $(whoami) != root

# string comparisons
var="foo bar"
IS "$var" =~ foo
IS "$var" =~ bar$
IS "$var" != foo
IS "$var" != "foobar"
IS "$var" =~ ^foo

# work with numbers
IS 10 -gt 5
IS 10 -ge 10

# expected negations
ISNT "$var" == foo
ISNT "$var" =~ ^bar

nonempty=1
OK -n "$nonempty"

empty=
OK -z "$empty"

OK -f /etc/passwd

# expected negations
NOK -w /etc/passwd

nonempty=1
OK -n "$nonempty"

empty=
OK -z "$empty"

OK -f /etc/passwd

# verify this exits successfully
RUNS true

# verify stdio empty
NGREP .
# verify specifically stdout empty
NOGREP .
# verify specifically stderr empty
NEGREP .

# verify this does not exit successfully
NRUNS cat /does/not/exist

# verify stdio
GREP "No such file"
# verify stderr
EGREP "No such file"

RUNS echo -e 'foo\nbar\nbaz'
# verify stdio
GREP bar
GREP ^foo
GREP ^baz
# verify stdout
OGREP bar
OGREP ^foo
OGREP ^baz

# diff stdout
DIFF <<EOF
foo
bar
baz
EOF
