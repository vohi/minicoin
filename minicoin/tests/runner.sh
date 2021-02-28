#!/usr/bin/env bash
set -o pipefail
declare -i errors=0
GREEN="\033[0;32m"
YELLOW="\e[0;33m"
RED="\033[0;31m"
NOCOL="\033[0m"

testcases=()
if [ "$1" == "--tests" ]
then
    IFS=','; testcases=( $2 )
    shift
    shift
fi

function run_case()
{
    [ ${#testcases[@]} == 0 ] && return 0

    for testcase in ${testcases[@]}
    do
        [ "$testcase" == "$1" ] && return 0
    done
    return 1
}

function assert()
{
    actual="$1"
    actual="${actual//$'\r'/}"
    expected="$2"
    if [[ "$actual" != "$expected" ]]; then
      printf "${RED}FAIL - %s\n" "$(cmp <(echo $actual) <(echo $expected))"
      printf "\t${YELLOW}'%s'${NOCOL} vs\n" "$actual"
      printf "\t'%s'${NOCOL}\n" "$expected"
      errors=$(( $errors + 1 ))
#    else
#      printf "${GREEN}PASS '$1' equals '$2'${NOCOL}\n"
    fi
}

function finish() {
    [ $errors -gt 0 ] && printf "${RED}" || printf "${GREEN}"
    printf "Done with $errors error!${NOCOL}\n"
}

if (run_case "parse-opts")
then
    echo "============================> Testing parse-opts  <============================"
    ./parse-opts-test.sh
    [ $? -gt 0 ] && errors=$(( $errors + 1 ))
fi

if (run_case "Vagrantfile")
then
    echo "============================> Testing Vagrantfile <============================"
    ruby autotest.rb
    error=$?
    [ $error -gt 0 ] && errors=$(( $errors + $error ))
fi

echo "=========================> Testing minicoin commands <========================="

if (run_case "list")
then
    echo "=== Testing list"
    minicoin list > /dev/null
    error=$?
    assert $error 0
fi

if (run_case global)
then
    echo "=== Testing in global environment"
    cd ..

    minicoin list --machine-readable | cut -d ',' -f 6 | (
        while read machine
        do
            echo "    $machine"
            minicoin describe $machine > /dev/null
            error=$?
            [ $error -gt 0 ] && errors=$(( $errors + $error ))
        done
    )
    [ $error -gt 0 ] && errors=$(( $errors + $error ))

    printf "  = Returning to test environment "
    cd -
fi

if [ $# -eq 0 ]
then
    echo "For additional tests, provide names of running machines!"
    finish
    exit $error
fi

echo "============================> Testing job running <============================"

if (run_case run)
then
    machines=( "${@}" )

    count=${#machines[@]}
    echo "Running test on $count machines in sequence"
    minicoin run --jobconfig 0 test ${machines[@]} -- error 2> /dev/null > /dev/null
    return=$?
    assert $return $count

    if [ $count -gt 1 ]
    then
        if [[ $errors -gt 0 ]]
        then
            printf "${RED}Skipping advanced tests due to earlier errors${NOCOL}\n"
        else
            echo "Running test on $count machines in parallel"
            minicoin run --parallel --jobconfig 0 test "${machines[@]}" 2> /dev/null > /dev/null
            return=$?
            assert $return 0

            minicoin run --parallel --jobconfig 0 test "${machines[@]}" -- error 2> /dev/null > /dev/null
            return=$?
            assert $return $count
        fi
    fi
fi

finish
exit $errors
