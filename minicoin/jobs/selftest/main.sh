. /opt/minicoin/util/parse-opts.sh "$@"

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
    cd /opt/minicoin/tests
    . parse-opts-test.sh
    exit $?
fi

echo "Hello runner!"
echo "This is $(uname -a)"
echo "Args received:"
exitcode=0
flood=0
for arg in "${@}"; do
  echo \'$arg\'
  [[ "$arg" = "error" ]] && exitcode=42
  [[ "$arg" = "flood" ]] && flood=1
done

repeats=3
[[ $flood -gt 0 ]] && repeats=1000
echo "Testing stdout and stderr"
for i in $(seq 1 ${repeats})
do
  echo "- stdout $i"
  >&2 echo "- stderr $i"
  [[ $flood -gt 0 ]] || sleep 1
done

if [ "$exitcode" -gt 0 ]
then
  >&2 echo "Exiting with error code $exitcode"
else
  echo "Exiting without errors"
fi
exit $exitcode
