# Obvious Shell Testing (osht)

## Synopsis
`osht` can be used to trivally test command line clients:
* verify exit codes
* verify message exists in stdout, stderr or either
* use standard shell test to verify side effects (file exits etc)
* produces TAP output (with --verbose option to see detailed input)
* produces JUNIT test xml file for easy integration with Jenkins

Start a test with:
```bash
#!/bin/bash
. osht.sh
```

Or import `osht` remotely:
```bash
#!/bin/bash
eval "$(curl -q -s https://raw.githubusercontent.com/coryb/osht/master/osht.sh)"
```

Next is it recommended to set a test plan so `osht` can know how many tests are expected to run (to be able to detect early crash).

```bash
PLAN 32
```

## Writing Tests
### Basic Comparisons
```bash
# simple command output
IS $(whoami) != root

# string comparisons
var="foobar"
IS "$var" =~ foo
IS "$var" =~ bar$
IS "$var" != foo
IS "$var" != "foo bar"
IS "$var" =~ ^foo

# work with numbers
IS 10 -gt 5
IS 10 -ge 10

# expected negations
ISNT "$var" == foo
ISNT "$var" =~ ^bar
```

### Basic Tests
```bash
nonempty=1
OK -n "$nonempty"

empty=
OK -z "$empty"

OK -f /etc/passwd

# expected negations
NOK -w /etc/passwd
```

### Run Commands
```
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

# diff output
DIFF <<EOF
foo
bar
baz
EOF
```

### TODO Tests

```
# you can mark known failures as TODO tests
# where you aspire to fix these and document
# the intended use case
TODO IS "$var" == foo
TODO ISNT "$var" != foo
TODO IS $((1 + 1)) = 3
TODO OK -z "$nonempty"
TODO OK -w /etc/passwd
TODO RUNS false
```

### SKIP Tests

```
# you can mark known test cases as SKIP when then
# are known not to run under some condition
SKIP test $(uname -s) == Darwin # Tests dont run under Darwin
```

#### Running Skip Tests

```
$ ./t/skip.t
1..0 # SKIP test $(uname -s) == Darwin # Tests dont run under Darwin
```

## Running Tests

### TAP Output

```bash
./t/example.t
1..32
ok 1 - IS $(whoami) != root
ok 2 - IS "$var" =~ foo
ok 3 - IS "$var" =~ bar$
ok 4 - IS "$var" != foo
ok 5 - IS "$var" != "foobar"
ok 6 - IS "$var" =~ ^foo
ok 7 - IS 10 -gt 5
ok 8 - IS 10 -ge 10
ok 9 - ISNT "$var" == foo
ok 10 - ISNT "$var" =~ ^bar
ok 11 - OK -n "$nonempty"
ok 12 - OK -z "$empty"
ok 13 - OK -f /etc/passwd
ok 14 - NOK -w /etc/passwd
ok 15 - OK -n "$nonempty"
ok 16 - OK -z "$empty"
ok 17 - OK -f /etc/passwd
ok 18 - RUNS true
ok 19 - NGREP .
ok 20 - NOGREP .
ok 21 - NEGREP .
ok 22 - NRUNS cat /does/not/exist
ok 23 - GREP "No such file"
ok 24 - EGREP "No such file"
ok 25 - RUNS echo -e 'foo\nbar\nbaz'
ok 26 - GREP bar
ok 27 - GREP ^foo
ok 28 - GREP ^baz
ok 29 - OGREP bar
ok 30 - OGREP ^foo
ok 31 - OGREP ^baz
ok 32 - DIFF <<EOF
not ok 33 - TODO IS "$var" == foo # TODO Test Know to fail
not ok 34 - TODO ISNT "$var" != foo # TODO Test Know to fail
not ok 35 - TODO IS $((1 + 1)) = 3 # TODO Test Know to fail
not ok 36 - TODO OK -z "$nonempty" # TODO Test Know to fail
not ok 37 - TODO OK -w /etc/passwd # TODO Test Know to fail
not ok 38 - TODO RUNS false # TODO Test Know to fail
```

### Using prove
```bash
$ prove
t/example.t .. ok
All tests successful.
Files=1, Tests=38,  0 wallclock secs ( 0.03 usr  0.01 sys +  0.14 cusr  0.32 csys =  0.50 CPU)
Result: PASS
```

### Junit Output
```bash
./t/example.t -j
1..38
...

$ ls -l t/example.t-tests.xml
-rw-r--r--  1 user  group  6551 Jun  9 14:47 t/example.t-tests.xml

$ file t/example.t-tests.xml
t/example.t-tests.xml: XML  document text
```

### Junit with prove
just set the `OSHT_JUNIT` environment variable and `osht` will generate junit xml files along with normal TAP output
when run under `prove`
```bash
$ OSHT_JUNIT=1 prove
t/example.t .. ok
All tests successful.
Files=1, Tests=38,  1 wallclock secs ( 0.03 usr  0.01 sys +  0.37 cusr  0.87 csys =  1.28 CPU)
Result: PASS

$ ls -l t/example.t-tests.xml
-rw-r--r--  1 user  group  6551 Jun  9 14:47 t/example.t-tests.xml

$ file t/example.t-tests.xml
t/example.t-tests.xml: XML  document text
```
