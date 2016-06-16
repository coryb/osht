#!/bin/bash
set -eu
. osht.sh

PLAN 10

JUNIT=1
_TESTING=1
_JUNIT=$STDIO

RUNS echo "hi"
DIFF <<'EOF'
hi
  <testcase classname="osht" name="001 - RUNS echo &quot;hi&quot;" time="0" timestamp="2016-01-01T08:00:00">
    <system-err><![CDATA[]]></system-err>
    <system-out><![CDATA[hi]]></system-out>
  </testcase>
EOF

wrapErr(){
local _TODO=1
NRUNS echo "hi there"
}
wrapErr
DIFF <<'EOF'
hi there
  <testcase classname="osht" name="003 - NRUNS echo &quot;hi there&quot;" time="0" timestamp="2016-01-01T08:00:00">
    <failure message="test failed"><![CDATA[RUNNING: echo hi\ there
STATUS: 0
STDIO <<EOM
hi there
EOM]]></failure>
    <system-err><![CDATA[]]></system-err>
    <system-out><![CDATA[hi there]]></system-out>
  </testcase>
EOF

TODO NRUNS echo "hi there"
DIFF <<'EOF'
hi there
  <testcase classname="osht" name="005 - TODO NRUNS echo &quot;hi there&quot;" time="0" timestamp="2016-01-01T08:00:00">
    <failure message="test failed"><![CDATA[RUNNING: echo hi\ there
STATUS: 0
STDIO <<EOM
hi there
EOM]]></failure>
    <system-err><![CDATA[]]></system-err>
    <system-out><![CDATA[hi there]]></system-out>
  </testcase>
EOF

echo -n > $STDIO
this=a
that=b
TODO IS "$this" == "$that"
DIFF <<'EOF'
  <testcase classname="osht" name="007 - TODO IS &quot;$this&quot; == &quot;$that&quot;" time="0" timestamp="2016-01-01T08:00:00">
    <failure message="test failed"><![CDATA[a == b]]></failure>
    <system-err><![CDATA[]]></system-err>
    <system-out><![CDATA[hi there]]></system-out>
  </testcase>
EOF

echo -n > $STDIO
nonempty="what"
TODO OK -z "$nonempty"
DIFF <<'EOF'
  <testcase classname="osht" name="009 - TODO OK -z &quot;$nonempty&quot;" time="0" timestamp="2016-01-01T08:00:00">
    <failure message="test failed"><![CDATA[test -z what]]></failure>
    <system-err><![CDATA[]]></system-err>
    <system-out><![CDATA[hi there]]></system-out>
  </testcase>
EOF
