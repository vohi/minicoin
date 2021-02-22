#!/usr/bin/env bash
set -o pipefail
declare -i errors=0
GREEN="\033[0;32m"
YELLOW="\e[0;33m"
RED="\033[0;31m"
NOCOL="\033[0m"

testcases=()
if [ $1 == "--tests" ]
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

if (run_case "runinfo")
then
    echo "=== Testing runinfo"
    assert "$(minicoin runinfo empty --machine-readable 2>&1 | grep warn | cut -d ',' -f 5)" \
    "==> empty: the host path '${PWD}' doesn't map to any location on the guest:"

    # prints: name os communicator guest_homes host_user home_share guest_pwd
    assert "$(minicoin runinfo --machine-readable test_linux | grep Minicoin::Commands::RunInfo | cut -d ',' -f 5-)" \
        "test_linux,linux,ssh,/home,${USER},${HOME},${PWD/"$HOME"//home/tester}"
    assert "$(minicoin runinfo --machine-readable test_windows | grep Minicoin::Commands::RunInfo | cut -d ',' -f 5-)" \
        "test_windows,windows,winrm,C:\\Users,${USER},${HOME},${PWD/"$HOME"/C:\\Users\\tester}"
    assert "$(minicoin runinfo --machine-readable test_mac | grep Minicoin::Commands::RunInfo | cut -d ',' -f 5-)" \
        "test_mac,macos,ssh,/Users,${USER},${HOME},${PWD/"$HOME"//Users/tester}"
    assert "$(minicoin runinfo --machine-readable test_linux test_mac test_windows | grep Minicoin::Commands::RunInfo | cut -d ',' -f 5-)" \
"test_linux,linux,ssh,/home,${USER},${HOME},${PWD/"$HOME"//home/tester}
test_mac,macos,ssh,/Users,${USER},${HOME},${PWD/"$HOME"//Users/tester}
test_windows,windows,winrm,C:\\Users,${USER},${HOME},${PWD/"$HOME"/C:\\Users\\tester}"
    assert "$(minicoin runinfo test --machine-readable | grep Minicoin::Commands::RunInfo | cut -d ',' -f 5-)" \
        "test,linux,ssh,/home,${USER},${HOME},${PWD/"$HOME"//home/vagrant}" # this machine uses mutagen
fi

if (run_case "jobconfig")
then
    echo "=== Testing jobconfig"
#    echo "    Interactive"
#    IFS=$'\n'; jobconfig=( $(minicoin jobconfig --job test test) )
#    assert "$(echo ${jobconfig[0]})" "--param1"

    echo "    No tty"
    assert "$(minicoin jobconfig --job test test --no-tty 2>&1 | tail -n1)" "with TTY."

    echo "    Piped"
    assert "$(echo "0" | minicoin jobconfig --job test test 2>&1 | head -n1)" "Multiple job configurations are available:"
    assert "$(echo "1" | minicoin jobconfig --job test test  2>&1 | tail -n1)" "\"hello \\\"world\\\"\""
    echo "    Named"
    assert "$(minicoin jobconfig --job test --config simple test)" \
"--param1
value1
--param2
value2
--flag"
    assert "$(minicoin jobconfig --job test --config complicated test)" \
"--array1
entry1,entry2
--spacey
\"foo bar\"
--quoted
\"hello \\\"world\\\"\""
    echo "    Indexed"
    assert "$(minicoin jobconfig --job test --index 0 test)" "$(minicoin jobconfig --job test --config simple test)"
    assert "$(minicoin jobconfig --job test --index 1 test)" "$(minicoin jobconfig --job test --config complicated test)"
    assert "$(minicoin jobconfig --job test --index 2 test)" ""
fi

if (run_case global)
then
    echo "=== Testing in global environment"
    cd ..

    minicoin list --machine-readable | cut -d ',' -f 6 | (
        while read machine
        do
            echo "    $machine"
            minicoin runinfo $machine > /dev/null
            error=$?
            [ $error -gt 0 ] && errors=$(( $errors + $error ))
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
machines=( "${@}" )

count=${#machines[@]}
echo "Running test on $count machines independently"

for machine in "${machines[@]}"
do
    echo "---- $machine - stdout"
    stdout="$(minicoin run --no-color $machine test 2> /dev/null | grep 'Hello')"
    return=$?
    assert $return 0
    assert "$stdout" "Hello runner!"

    echo "---- $machine - stderr"
    stderr="$(minicoin run --no-color $machine test -- error 2>&1 > /dev/null | grep 'error code')"
    return=$?
    assert $return 1
    assert "$stderr" "Exiting with error code 1"
    [ $errors -gt 0 ] && printf "${RED}Finished on $machine with $errors errors!${NOCOL}\n"
done

if [ $count -gt 1 ]
then
    echo "Running test on $count machines sequentially"
    minicoin run ${machines[@]} test -- error 2> /dev/null > /dev/null
    return=$?
    assert $return $count

    echo "Running test on $count machines in parallel"
    minicoin run --parallel "${machines[@]}" test 2> /dev/null > /dev/null
    return=$?
    assert $return 0

    minicoin run --parallel "${machines[@]}" test -- error 2> /dev/null > /dev/null
    return=$?
    assert $return $count
fi

finish
exit $errors
