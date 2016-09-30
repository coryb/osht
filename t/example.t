#!/bin/bash
set -eu
. osht.sh

PLAN 42

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

# you can mark known failures as TODO tests
# where you aspire to fix these and document
# the intended use case
TODO IS "$var" == foo
TODO ISNT "$var" != foo
TODO IS $((1 + 1)) = 3
TODO OK -z "$nonempty"
TODO OK -w /etc/passwd
TODO RUNS false

RUNS bash -c 'for i in $(seq 1 10); do echo $i >&$(($i%2+1)); sleep 1; done'
DIFF <<EOF
1
2
3
4
5
6
7
8
9
10
EOF

EDIFF <<EOF
1
3
5
7
9
EOF

ODIFF <<EOF
2
4
6
8
10
EOF
