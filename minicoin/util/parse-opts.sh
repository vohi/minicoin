names=()
args=()
POSITIONAL=()
FLAGS=()
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
  if [[ "$arg" == '""' ]]; then
    FLAGS=( ${FLAGS[@]} "$name" )
    declare "FLAG_$name"="false"
  elif [[ $name != "" ]]; then
    param="PARAM_$name";
    value=${!param}
    if [[ $value ]]; then
      echo "$param already set to '$value' - ignoring $arg"
    else
      declare "$param"="$arg"
    fi
  fi
done
