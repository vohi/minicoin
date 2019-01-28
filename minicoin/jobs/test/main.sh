echo "Hello runner!"
echo "Args received:"
for arg in ${@}; do
  echo \'$arg\'
done
>&2 echo "Testing stderr"
