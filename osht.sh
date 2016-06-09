_CURRENT_TEST=0
_PLANNED_TESTS=
JUNIT_OUTPUT=tests.xml
JUNIT=
VERBOSE=
_START=
_LAPSE=

declare -a _ARGS

_CURRENT_TEST_FILE=$(mktemp)
_FAILED_FILE=$(mktemp)
STDOUT=$(mktemp)
STDERR=$(mktemp)
STDIO=$(mktemp)
_JUNIT=$(mktemp)

function _usage {
    [ -n "${1:-}" ] && echo -e "Error: $1\n" >&2
    cat <<EOF
Usage: $(basename $0) [--output <junit-output-file>] [--junit] [--verbose]
EOF
    exit 0
}


while true; do
    [[ $# == 0 ]] && break
    case $1 in
        -o | --output) JUNIT_OUTPUT=$2; shift 2 ;;
        -j | --junit)  JUNIT=1; shift ;;
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
    fi
    if [[ $_PLANNED_TESTS != $_CURRENT_TEST ]]; then
        echo "$_PLANNED_TESTS tests expected but $_CURRENT_TEST ran" >&2
        exit 1
    fi
    if [[ -n $JUNIT ]]; then
        _init_junit > $JUNIT_OUTPUT
        cat $_JUNIT >> $JUNIT_OUTPUT
        _end_junit >> $JUNIT_OUTPUT
    fi
    rm -f $STDOUT $STDERR $STDIO $_CURRENT_TEST_FILE $_JUNIT
    exit $rv
}

trap _cleanup INT TERM EXIT

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
        failure="<failure message=\"test failed\"><![CDATA[$(_qq "${_ARGS[@]}")]]></failure>\n    "
    fi
    local stdout=$(cat $STDOUT)
    local stderr=$(cat $STDERR)
    local _DEPTH=$(($_DEPTH+1))
    cat <<EOF >> $_JUNIT
  <testcase classname="$(_source)" name="$(_get_line)" time="$_LAPSE" timestamp="$(_timestamp)">
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

_DEPTH=2
function _source {
    local parts=($(caller $_DEPTH))
    echo ${parts[2]}:${parts[0]}
}

function _get_line {
    local parts=($(caller $_DEPTH))
    sed "${parts[0]}q;d" ${parts[2]}
}

function _increment_test {
    _CURRENT_TEST=$(cat $_CURRENT_TEST_FILE)
    let _CURRENT_TEST=_CURRENT_TEST+1
    echo $_CURRENT_TEST > $_CURRENT_TEST_FILE
    _start
}

function _increment_failed {
    local _FAILED=$(cat $_FAILED_FILE)
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
    echo "ok $_CURRENT_TEST - $(_get_line)"
    _add_junit
}

function _nok {
    _stop
    _debug
    _increment_failed
    echo "not ok $_CURRENT_TEST - $(_get_line)"
    _add_junit "${_ARGS[@]}"
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
    parts=($(caller 2))
    case ${parts[1]} in
        IS)
            _qq "${_ARGS[@]}";;
        ISNT)
            _qq \! "${_ARGS[@]}";;
        OK)
            _qq test "${_ARGS[@]}";;
        NOK)
            _qq test \! "${_ARGS[@]}";;
        NRUNS|RUNS)
            echo "RUNNING: $(_qq ${_ARGS[@]})"
            echo "STATUS: $STATUS"
            echo "STDIO <<EOM"
            cat $STDIO
            echo "EOM";;
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
    eval [[ "$1" $2 "$3" ]] && _ok || _nok
}

function ISNT {
    _args "$@"
    _increment_test
    eval [[ ! "$1" $2 "$3" ]] && _ok || _nok
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
