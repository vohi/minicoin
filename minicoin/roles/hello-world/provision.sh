. /minicoin/util/parse-opts.sh "$@"

[[ ! -z $PARAM_welcome ]] && welcome=$PARAM_welcome || welcome="Hello world,"
echo "$welcome $3"

if [[ $FLAG_debug != true ]]; then
  exit 0
fi

echo "All arguments: $@"
echo "Named:"
for p in ${PARAMS[@]}; do
  name="PARAM_$p"
  pv1="${name}[1]"
  pv1="${!pv1}"
  if [ "$pv1" != "" ]; then
    echo "- $p"
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
