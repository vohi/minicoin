#!/usr/bin/env bash

declare -a args=( pos1 pos2 --param1 value1 --param2 value2 pos3 --flag1 --param3 value3 --array "a 1" --array "a 2" --flag2 --array a3 "pos 4" --flag3 )
declare -i errors=0

function assert()
{
    if [[ "$1" != "$2" ]]; then
      echo "FAIL '$1' vs '$2'"
      errors+=1
#    else
      # echo "PASS $1 equals $2"
    fi
}

. parse-opts.sh "${args[@]}"

assert "${POSITIONAL[*]}" "pos1 pos2 pos3 pos 4"
assert ${POSITIONAL[0]} "pos1"
assert ${POSITIONAL[1]} "pos2"
assert ${POSITIONAL[2]} "pos3"
assert "${POSITIONAL[3]}" "pos 4"

assert "${FLAGS[*]}" "flag1 flag2 flag3"
assert "$FLAG_flag1" "true"
assert "$FLAG_flag2" "true"
assert "$FLAG_flag3" "true"
assert "$FLAG_flag4" ""

assert "${PARAMS[*]}" "param1 param2 param3 array"
assert $PARAM_param1 "value1"
assert $PARAM_param2 "value2"
assert $PARAM_param3 "value3"
assert "$PARAM_array" "a 1"

assert "${PARAM_array[*]}" "a 1 a 2 a3"
assert "${PARAM_array[0]}" "a 1"
assert "${PARAM_array[1]}" "a 2"
assert "${PARAM_array[2]}" "a3"

if [[ $errors -gt 0 ]]; then
  echo "$errors errors!"
  exit 1
else
  echo "No errors!"
  exit 0
fi