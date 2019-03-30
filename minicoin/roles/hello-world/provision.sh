. /minicoin/util/parse-opts.sh "$@"

echo "Hello world, $3"

if [[ $FLAG_debug != true ]]; then
  exit 0
fi

echo "All arguments: $@"
echo "Named:"
for p in ${PARAMS[@]}; do
  name="PARAM_$p"
  echo "- $p: ${!name}"
done
echo "Positional:"
for p in ${POSITIONAL[@]}; do
  echo "- $p"
done
echo "Flags:"
for f in ${FLAGS[@]}; do
  echo "- $f"
done
