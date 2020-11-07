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
  elif [[ "$arg" =~ ^--.*$ ]]; then
    if [[ ${#args[@]} < ${#names[@]} ]]; then
      args+=('""')
    fi
    name="${arg/--/}"
    names+=("$name")
  elif [[ "$arg" =~ ^-.$ ]]; then
    if [[ ${#args[@]} < ${#names[@]} ]]; then
      args+=('""')
    fi
    name=${arg/-/}
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

_JOBDIR="${POSITIONAL[1]}"
HOST_HOME="${POSITIONAL[0]}"
HOST_USER=$(basename $HOST_HOME)
[ -d /Users ] && MOUNTED_HOME="/Users" || MOUNTED_HOME="/home"
[ -d "$MOUNTED_HOME/$HOST_USER" ] && MOUNTED_HOME="$MOUNTED_HOME/$HOST_USER" || MOUNTED_HOME="$MOUNTED_HOME/host"
JOBDIR="${_JOBDIR/$HOST_HOME/$HOME}"
if [ ! -d "$JOBDIR" ]
then
  JOBDIR="${_JOBDIR/$HOST_HOME/$MOUNTED_HOME}"
fi

unset _JOBDIR
unset _HOST_HOME
unset HOST_HOME
unset MOUNTED_HOME
