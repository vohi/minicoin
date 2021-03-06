names=()
args=()
POSITIONAL=()
FLAGS=()
PARAMS=()
PASSTHROUGH=()
count=()
index=0

for arg in "${@}"; do
  count+=($index)
  index=$(( index + 1 ))

  if [[ "$arg" == "--" ]]; then
    PASSTHROUGH=( "${@:$(( index + 1 ))}" )
    break
  fi
  is_name=""
  if [[ ! "$arg" =~ " " ]]; then
    if [[ "$arg" =~ ^--.*$ ]]; then
      name="${arg/--/}"
      is_name="true"
    elif [[ "$arg" =~ ^-.$ ]]; then
      name="${arg/-/}"
      is_name="true"
    fi
  fi
  if [[ ! -z $is_name ]]; then
    if [[ ${#args[@]} < ${#names[@]} ]]; then
      args+=('""')
    fi
    names+=("$name")
  else
    if [[ ${#names[@]} == ${#args[@]} ]]; then
      POSITIONAL+=("$arg")
    else
      args+=("$arg")
    fi
  fi
done

for i in ${count[@]}; do
  arg=${args[$i]}
  name=${names[$i]}
  name="${name//-/_}"

  if [[ $name != "" ]]; then
    if [[ "$arg" == '""' ]] || [[ $arg == "" ]]; then
      FLAGS+=("$name")
      declare "FLAG_$name"="true"
    elif [[ "${PARSE_OPTS_FLAGS[@]}" =~ "$name" ]]; then
      FLAGS+=("$name")
      declare "FLAG_$name"="true"
      POSITIONAL+=("$arg")
    else
      param="PARAM_$name";
      value=${!param}
      if [[ $value ]]; then
        declare "$param+=('$arg')"
      else
        declare -a "$param=('$arg')"
        PARAMS+=("$name")
      fi
    fi
  fi
done

unset index
unset names
unset args
unset count

JOBDIR="${POSITIONAL[0]}"

if [ ! -d "$JOBDIR" ]
then
  >&2 echo "Folder '$JOBDIR' does not exist on this guest - couldn't map to a shared folder"
fi
