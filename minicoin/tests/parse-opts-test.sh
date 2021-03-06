#!/usr/bin/env bash

PARSE_OPTS_FLAGS=(
  flag4
)
args=( $HOME
  pos2
  --param1 value1
  --param2 value2
  pos3
  --flag1
  --param3 value3
  --array "a 1" --array "a 2"
  --flag2
  --array a3
  "pos 4"
  --flag3
  --flag4
  pos5
  --param4 "--value4 123 --value5"
  -- pass "pass through" --pass
)
declare -i errors=0

function assert()
{
    if [[ "$1" != "$2" ]]; then
      echo "FAIL '$1' vs '$2'"
      errors=$(( errors + 1 ))
#    else
      # echo "PASS $1 equals $2"
    fi
}

if [[ $1 == --debug ]]; then
  debug=true
  shift
  unset args
  args=( "$@" )
  echo "Testing ${args[*]}"
fi

. ../util/parse-opts.sh "${args[@]}"

if [[ $debug == true ]]; then
  echo "Positional: ${POSITIONAL[@]}"
  for p in ${POSITIONAL[@]}; do echo "- $p"; done
  echo "Flags: ${FLAGS[@]}"
  for f in ${FLAGS[@]}; do echo "- $f"; done
  echo "Params: ${PARAMS[@]}"
  for p in ${PARAMS[@]}; do
    name="PARAM_$p"
    value="${!name}"
    echo "- $p: $value"
  done
  echo "Pass-through: ${PASSTHROUGH}"
  exit 0
fi

assert "${POSITIONAL[*]}" "$HOME pos2 pos3 pos 4 pos5"
assert "${#POSITIONAL[@]}" 5
assert ${POSITIONAL[0]} "$HOME"
assert ${POSITIONAL[1]} "pos2"
assert ${POSITIONAL[2]} "pos3"
assert "${POSITIONAL[3]}" "pos 4"
assert "${POSITIONAL[4]}" "pos5"

assert "${FLAGS[*]}" "flag1 flag2 flag3 flag4"
assert "${#FLAGS[@]}" 4
assert "$FLAG_flag1" "true"
assert "$FLAG_flag2" "true"
assert "$FLAG_flag3" "true"
assert "$FLAG_flag4" "true"
assert "$FLAG_flag5" ""

assert "${PARAMS[*]}" "param1 param2 param3 array param4"
assert "${#PARAMS[@]}" 5
assert $PARAM_param1 "value1"
assert $PARAM_param2 "value2"
assert $PARAM_param3 "value3"
assert "$PARAM_array" "a 1"
assert "$PARAM_param4" "--value4 123 --value5"

assert "${PARAM_array[*]}" "a 1 a 2 a3"
assert "${#PARAM_array[@]}" 3
assert "${PARAM_array[0]}" "a 1"
assert "${PARAM_array[1]}" "a 2"
assert "${PARAM_array[2]}" "a3"

assert "${PASSTHROUGH[*]}" "pass pass through --pass"
assert "${#PASSTHROUGH[@]}" 3
assert "${PASSTHROUGH[0]}" "pass"
assert "${PASSTHROUGH[1]}" "pass through"
assert "${PASSTHROUGH[2]}" "--pass"

if [[ $errors -gt 0 ]]; then
  echo "$errors errors!"
  exit 1
else
  echo "No errors!"
  exit 0
fi