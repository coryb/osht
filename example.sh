#!/bin/bash
. osht.sh

PLAN 30

IS "foobar" == "foobar"
IS bar == bar
IS bar != bear
IS foobar =~ bar
ISNT foobar =~ ^bar
IS foobar =~ ^foo
IS foobar =~ bar$

nonempty=1
OK -n "$nonempty"

empty=
OK -z "$empty"

OK -f /etc/passwd

RUNS true

NRUNS false

RUNS echo -e 'foo\nbar\nbaz'
GREP bar
GREP ^foo
GREP ^baz
OGREP bar
OGREP ^foo
OGREP ^baz

NGREP blorg
NGREP ^beep
NOGREP blorg
NOGREP ^beep
NEGREP blorg
NEGREP ^beep

NRUNS cat /does/not/exist
GREP "No such file"
EGREP "No such file"
NOGREP .

RUNS sleep 2
