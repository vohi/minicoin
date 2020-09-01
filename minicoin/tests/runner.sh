#!/usr/bin/env bash
set -o pipefail

echo "============================> Testing parse-opts  <============================"
./parse-opts-test.sh

echo "============================> Testing Vagrantfile <============================"
ruby autotest.rb

echo "============================> Testing job running <============================"
machines=( "${@}" )
if [ $# -eq 0 ]
then
    echo "For additional tests, provide names of running machines!"
    exit
fi

GREEN="\033[0;32m"
RED="\033[0;31m"
NOCOL="\033[0m"

declare -i errors=0
function assert()
{
    actual="$1"
    actual="${actual//$'\r'/}"
    expected="$2"
    if [[ "$actual" != "$expected" ]]; then
      printf "${RED}FAIL '$actual' vs '$expected'${NOCOL}\n"
      errors=$(( errors + 1 ))
#    else
#      printf "${GREEN}PASS '$1' equals '$2'${NOCOL}\n"
    fi
}

count=${#machines[@]}
echo "Running test on $count machines independently"

for machine in "${machines[@]}"
do
    echo "---- $machine - stdout"
    stdout="$(minicoin run $machine test 2> /dev/null | grep 'Hello')"
    return=$?
    assert $return 0
    assert "$stdout" "Hello runner!"

    echo "---- $machine - stderr"
    stderr="$(minicoin run $machine test -- error 2>&1 > /dev/null | grep 'error code')"
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

[ $errors -gt 0 ] && printf "${RED}" || printf "${GREEN}"
printf "Done with $errors error!${NOCOL}\n"
