. /minicoin/util/parse-opts.sh "$@"

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
