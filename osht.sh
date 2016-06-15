: ${_CURRENT_TEST=0}
: ${_PLANNED_TESTS=}
: ${JUNIT=}
: ${VERBOSE=}
: ${_START=}
: ${_LAPSE=}
: ${_CURRENT_TEST_FILE=$(mktemp)}
: ${_FAILED_FILE=$(mktemp)}
: ${STDOUT=$(mktemp)}
: ${STDERR=$(mktemp)}
: ${STDIO=$(mktemp)}
: ${_JUNIT=$(mktemp)}
: ${_DIFFOUT=$(mktemp)}
: ${_INITPATH=$(pwd)}
: ${JUNIT_OUTPUT="$(cd "$(dirname "$0")"; pwd)/$(basename "$0")-tests.xml"}
: ${ABORT=}
: ${_DEPTH=2}
: ${_TODO=}

declare -a _ARGS

function _usage {
    [ -n "${1:-}" ] && echo -e "Error: $1\n" >&2
    cat <<EOF
Usage: $(basename $0) [--output <junit-output-file>] [--junit] [--verbose] [--abort]
Options:
-a|--abort         On the first error abort the test execution
-h|--help          This help message
-j|--junit         Enable JUnit xml writing
-o|--output=<file> Location to write JUnit xml file [default: $JUNIT_OUTPUT]
-v|--verbose       Print extra output for debugging tests
EOF
    exit 0
}


while true; do
    [[ $# == 0 ]] && break
    case $1 in
        -a | --abort) ABORT=1; shift;;
        -h | --help) usage;;
        -j | --junit)  JUNIT=1; shift ;;
        -o | --output) JUNIT_OUTPUT=$2; shift 2 ;;
        -v | --verbose) VERBOSE=1; shift ;;
        -- ) shift; break ;;
        -* ) (_usage "Invalid argument $1") >&2 && exit 1;;
        * ) break ;;
    esac
done


function _cleanup {
    rv=$?
    if [ -z "$_PLANNED_TESTS" ]; then
        _PLANNED_TESTS=$_CURRENT_TEST
        echo "1..$_PLANNED_TESTS"
    fi
    if [[ -n $JUNIT ]]; then
        _init_junit > $JUNIT_OUTPUT
        cat $_JUNIT >> $JUNIT_OUTPUT
        _end_junit >> $JUNIT_OUTPUT
    fi
    local failed=$(_failed)
    rm -f $STDOUT $STDERR $STDIO $_CURRENT_TEST_FILE $_JUNIT $_FAILED_FILE $_DIFFOUT
    if [[ $_PLANNED_TESTS != $_CURRENT_TEST ]]; then
        echo "Looks like you planned $_PLANNED_TESTS tests but ran $_CURRENT_TEST." >&2
        rv=255
    fi
    if [[ $failed > 0 ]]; then
        echo "Looks like you failed $failed test of $_CURRENT_TEST." >&2
        rv=$failed
    fi
          
    exit $rv
}

trap _cleanup INT TERM EXIT

function _xmlencode {
    sed -e 's/\&/\&amp;/g' -e 's/\"/\&quot;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' 
}

function _strip_terminal_escape {
    sed -e $'s/\x1B\[[0-9]*;[0-9]*[m|K]//g' -e $'s/\x1B\[[0-9]*[m|K]//g'
}

function _timestamp {
    date "+%Y-%m-%dT%H:%M:%S"
}

function _init_junit {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites failures="$(_failed)" name="$0" tests="$_PLANNED_TESTS" time="$SECONDS" timestamp="$(_timestamp)" >
EOF
}

function _add_junit {
    if [[ -z $JUNIT ]]; then
        return
    fi
    failure=
    if [[ $# != 0 ]]; then
        failure="<failure message=\"test failed\"><![CDATA[$(_debugmsg | _strip_terminal_escape)]]></failure>\n    "
    fi
    local stdout=$(cat $STDOUT | _strip_terminal_escape)
    local stderr=$(cat $STDERR | _strip_terminal_escape)
    local _DEPTH=$(($_DEPTH+1))
    cat <<EOF >> $_JUNIT
  <testcase classname="$(_source)" name="$(printf "%03i" $_CURRENT_TEST) - $(_get_line | _xmlencode)" time="$_LAPSE" timestamp="$(_timestamp)">
    $failure<system-err><![CDATA[$stderr]]></system-err>
    <system-out><![CDATA[$stdout]]></system-out>
  </testcase>
EOF
}

function _end_junit {
    cat <<EOF
</testsuites>
EOF
}

function _source {
    local parts=($(caller $_DEPTH))
    local fn=$(basename ${parts[2]})
    echo ${fn%.*}
}

function _get_line {
    local parts=($(caller $_DEPTH))
    (cd $_INITPATH && sed "${parts[0]}q;d" ${parts[2]})
}

function _increment_test {
    _CURRENT_TEST=$(cat $_CURRENT_TEST_FILE)
    let _CURRENT_TEST=_CURRENT_TEST+1
    echo $_CURRENT_TEST > $_CURRENT_TEST_FILE
    _start
}

function _increment_failed {
    local _FAILED=$(_failed)
    let _FAILED=_FAILED+1
    echo $_FAILED > $_FAILED_FILE
}

function _failed {
    [[ -s $_FAILED_FILE ]] && cat $_FAILED_FILE || echo "0"
}

function _start {
    _START=$(date +%s)
}

function _stop {
    local _now=$(date +%s)
    _LAPSE=$(($_now - $_START))
}

function _ok {
    _stop
    _debug
    echo -n "ok $_CURRENT_TEST - $(_get_line)"
    if [ -n "$_TODO" ]; then
        echo " # TODO Test Know to fail"
    else
        echo
    fi
    _add_junit
}

function _nok {
    _stop
    _debug
    echo -n "not ok $_CURRENT_TEST - $(_get_line)"
    if [ -n "$_TODO" ]; then
        echo " # TODO Test Know to fail"
    else
        _increment_failed
        echo
    fi
    _add_junit "${_ARGS[@]}"
    if [ -n "$ABORT" ]; then
        exit 1
    fi
}

function _run {
    : >$STDOUT
    : >$STDERR
    : >$STDIO
    set +e
    { { "$@" | tee -- $STDOUT 1>&3 >> $STDIO; exit ${PIPESTATUS[0]}; } 2>&1 \
             | tee -- $STDERR 1>&2 >> $STDIO; } 3>&1
    STATUS=${PIPESTATUS[0]}
    set -e
}

function _qq {
    declare -a out
    for p in "$@"; do
        out+=($(printf %q "$p"))
    done
    local IFS=" "
    echo -n "${out[*]}"
}
        
function _debug {
    if [[ -n $VERBOSE ]]; then
        _debugmsg | sed 's/^/# /g'
    fi
}

function _debugmsg {
    local args=("${_ARGS[@]}")
    if [[ ${args[0]} == "TODO" ]]; then
        args=${args[@]:1}
    fi
    case ${args[0]} in
        IS)
            _qq "${args[@]}";;
        ISNT)
            _qq \! "${args[@]}";;
        OK)
            _qq test "${args[@]}";;
        NOK)
            _qq test \! "${args[@]}";;
        NRUNS|RUNS)
            echo "RUNNING: $(_qq ${args[@]})"
            echo "STATUS: $STATUS"
            echo "STDIO <<EOM"
            cat $STDIO
            echo "EOM";;
        DIFF|ODIFF|EDIFF)
            cat $_DIFFOUT;;
   esac
}

function _debugfile {
    if [[ -n $VERBOSE ]]; then
        printf "# $1 <<EOM\n"
        cat $2 | sed 's/^/# /g'
        printf "# EOM\n"
    fi
}

function _args {
    _ARGS=("$@")
}

function PLAN {
    echo "1..$1"
    _PLANNED_TESTS=$1
}

function IS {
    _args "$@"
    _increment_test
    case "$2" in
        =~) [[ $1 =~ $3 ]] && _ok || _nok;;
        !=) [[ $1 != $3 ]] && _ok || _nok;;
        =|==) [[ $1 == $3 ]] && _ok || _nok;;
        *) [ "$1" $2 "$3" ] && _ok || _nok;;
    esac
}

function ISNT {
    _args "$@"
    _increment_test
    case "$2" in
        =~) [[ ! $1 =~ $3 ]] && _ok || _nok;;
        !=) [[ $1 == $3 ]] && _ok || _nok;;
        =|==) [[ $1 != $3 ]] && _ok || _nok;;
        *) [ ! "$1" $2 "$3" ] && _ok || _nok;;
    esac
}

function OK {
    _args "$@"
    _increment_test
    test "$@" && _ok || _nok
}

function NOK {
    _args "$@"
    _increment_test
    test ! "$@" && _ok || _nok
}

function RUNS {
    _args "$@"
    _increment_test
    _run "$@"
    [[ $STATUS == 0 ]] && _ok || _nok
}

function NRUNS {
    _args "$@"
    _increment_test
    _run "$@"
    [[ $STATUS != 0 ]] && _ok || _nok
}

function GREP {
    _args "$@"
    _increment_test
    grep -q "$@" $STDIO && _ok || _nok
}

function EGREP {
    _args "$@"
    _increment_test
    grep -q "$@" $STDERR && _ok || _nok
}

function OGREP {
    _args "$@"
    _increment_test
    grep -q "$@" $STDOUT && _ok || _nok
}

function NGREP {
    _args "$@"
    _increment_test
    ! grep -q "$@" $STDIO  && _ok || _nok
}

function NEGREP {
    _args "$@"
    _increment_test
    ! grep -q "$@" $STDERR  && _ok || _nok
}

function NOGREP {
    _args "$@"
    _increment_test
    ! grep -q "$@" $STDOUT  && _ok || _nok
}

function DIFF {
    _args diff -u - $STDIO
    _increment_test
    diff -u - $STDIO | tee $_DIFFOUT | sed 's/^/# /g'
    [[ ${PIPESTATUS[0]} == 0 ]] && _ok || _nok
}

function ODIFF {
    _args diff -u - $STDOUT
    _increment_test
    diff -u - $STDOUT | tee $_DIFFOUT | sed 's/^/# /g'
    [[ ${PIPESTATUS[0]} == 0 ]] && _ok || _nok
}

function EDIFF {
    _args diff -u - $STDERR
    _increment_test
    diff -u - $STDERR | tee $_DIFFOUT | sed 's/^/# /g'
    [[ ${PIPESTATUS[0]} == 0 ]] && _ok || _nok
}

function TODO {
    local _TODO=1
    local _DEPTH=$(($_DEPTH+1))
    "$@"
}
