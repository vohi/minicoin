. /minicoin/util/parse-opts.sh "$@"

echo "Job works on '$JOBDIR'"

if [ ! -z "$FLAG_echo" ]; then
  echo "All arguments: $@"
  echo "Named:"
  for p in ${PARAMS[@]}; do
    name="PARAM_$p"
    pv1="${name}[1]"
    pv1="${!pv1}"
    if [ "$pv1" != "" ]; then
      echo "- $p[]"
      array="${name}[@]"
      for a in "${!array}"; do
        echo "  - $a"
      done
    else
      echo "- $p: ${!name}"
    fi
  done
  echo "Positional:"
  for p in ${POSITIONAL[@]}; do
    echo "- $p"
  done
  echo "Flags:"
  for f in ${FLAGS[@]}; do
    echo "- $f"
  done
  exit 0
fi

if [ ! -z "$FLAG_debug" ]; then
    echo "Running parse-opts-test"
    cd /minicoin/tests
    . parse-opts-test.sh
    exit $?
fi

echo "Hello runner!"
echo "This is $(uname -a)"
echo "Args received:"
exitcode=0
for arg in "${@}"; do
  echo \'$arg\'
  if [[ "$arg" = "error" ]]; then
     exitcode=1
     >&2 echo "Exiting with error code $exitcode"
  fi
done
>&2 echo "Testing stderr"
exit $exitcode
