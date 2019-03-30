names=()
args=()
POSITIONAL=()
FLAGS=()
PARAMS=()
count=()
index=0

for arg in "${@}"; do
  count=( ${count[@]} $index )
  index=$(( index + 1 ))

  if [[ "$arg" =~ ^--.*$ ]]; then
    if [[ ${#args[@]} < ${#names[@]} ]]; then
        args=( "${args[@]}" '""' )
    fi
    name=${arg/--/}
    names=( "${names[@]}" "$name" )
  elif [[ "$arg" =~ ^-.$ ]]; then
    if [[ ${#args[@]} < ${#names[@]} ]]; then
        args=( "${args[@]}" '""' )
    fi
    name=${arg/-/}
    names=( "${names[@]}" "$name" )
  else
    if [[ ${#names[@]} == ${#args[@]} ]]; then
        POSITIONAL=( "${POSITIONAL[@]}" "$arg" )
    else
        args=( "${args[@]}" "$arg" )
    fi
  fi
done

for i in ${count[@]}; do
  arg=${args[$i]}
  name=${names[$i]}
  name="${name//-/_}"

  if [[ "$arg" == '""' ]] || [[ $arg == "" ]]; then
    FLAGS=( ${FLAGS[@]} "$name" )
    declare "FLAG_$name"="true"
  elif [[ $name != "" ]]; then
    param="PARAM_$name";
    value=${!param}
    if [[ $value ]]; then
      declare "$param+=($arg)"
    else
      declare -a "$param=( '$arg' )"
      PARAMS=( ${PARAMS[@]} "$name" )
    fi
  fi
done
