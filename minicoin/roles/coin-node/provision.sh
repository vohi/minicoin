set +ex

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --coin-root)
      COINROOT="$2"
      shift
      shift
      ;;
    --template)
      TEMPLATE="$2"
      shift
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

echo "Provisioning from '$COINROOT' using template '$TEMPLATE'"

cd $COINROOT/provisioning
error=$?

if [[ $error != 0 ]]; then
  echo "'$COINROOT/provisioning' does not exist"
  exit $error
fi

cd $TEMPLATE
error=$?

if [[ $error != 0 ]]; then
  echo "No coin template '$TEMPLATE' in $PWD"
  exit 1
fi

SCRIPTS=( *.sh )

for script in ${SCRIPTS[@]}; do
  [ -e "$script" ] || continue
  echo "++ Executing '$script $@'"
  bash "./$script" $@ || true
done
