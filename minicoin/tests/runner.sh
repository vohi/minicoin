#!/usr/bin/env bash
set -o pipefail
declare -i errors=0
GREEN="\033[0;32m"
YELLOW="\e[0;33m"
RED="\033[0;31m"
NOCOL="\033[0m"


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

echo "============================> Testing parse-opts  <============================"
./parse-opts-test.sh
[ $? -gt 0 ] && errors=$(( $errors + 1 ))

echo "============================> Testing Vagrantfile <============================"
ruby autotest.rb
error=$?
[ $error -gt 0 ] && errors=$(( $errors + $error ))

echo "=========================> Testing minicoin commands <========================="

echo "=== Testing list"
minicoin list > /dev/null
error=$?
assert $error 0

echo "=== Testing runinfo"
assert "$(minicoin runinfo empty 2>&1)" \
"==> empty: the host path '${PWD}' doesn't map to any location on the guest:
empty linux ssh /home ${USER} ${HOME} ${PWD}"

# prints: name os communicator guest_homes host_user home_share guest_pwd
assert "$(minicoin runinfo test_linux)" "test_linux linux ssh /home ${USER} ${HOME} ${PWD/"$HOME"//home/tester}"
assert "$(minicoin runinfo test_windows)" "test_windows windows winrm C:\\Users ${USER} ${HOME} ${PWD/"$HOME"/C:\\Users\\tester}"
assert "$(minicoin runinfo test_mac)" "test_mac macos ssh /Users ${USER} ${HOME} ${PWD/"$HOME"//Users/tester}"
assert "$(minicoin runinfo test_linux test_mac test_windows)" \
"test_linux linux ssh /home ${USER} ${HOME} ${PWD/"$HOME"//home/tester}
test_mac macos ssh /Users ${USER} ${HOME} ${PWD/"$HOME"//Users/tester}
test_windows windows winrm C:\\Users ${USER} ${HOME} ${PWD/"$HOME"/C:\\Users\\tester}"

echo "=== Testing jobconfig"
assert "$(minicoin runinfo test)" "test linux ssh /home ${USER} ${HOME} ${PWD/"$HOME"//home/tester}"
assert "$(minicoin jobconfig --job runtest test)" "$(printf '0) A\t1) A\t2) B\t')"
assert "$(minicoin jobconfig --job runtest --config A test)" "$(printf '0) A\t1) A\t')"
assert "$(minicoin jobconfig --job runtest --config B test)" ""
assert "$(minicoin jobconfig --job runtest --index 2 test)" ""

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
