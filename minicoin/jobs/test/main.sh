echo "Hello runner!"
echo "Args received:"
exitcode=0
for arg in ${@}; do
  echo \'$arg\'
  if [[ "$arg" = "error" ]]; then
     exitcode=1
     >&2 echo "Exiting with error code $exitcode"
  fi
done
>&2 echo "Testing stderr"
exit $exitcode