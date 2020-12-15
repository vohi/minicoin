. /minicoin/util/parse-opts.sh "$@"

cd /minicoin/roles/coin-node/coin/provisioning

if [ $? -gt 0 ]
then
    >&2 echo "Can't find coin provisioning scripts"
    exit 1
fi

echo "Provisioning with template $PARAM_template"
cd $PARAM_template

if [ $? -gt 0 ]
then
    >&2 echo "Can't find coin template '$PARAM_template'"
    exit 2
fi

SCRIPTS=( *.sh )

[ -z ${ROLES[@]} ] && ROLES=( apt gcc libclang sccache fbx install-cmake version )

echo "Executing provisioning for '${ROLES[@]}'"

for script in ${SCRIPTS[@]}; do
  [ -e "$script" ] || continue
  step=$(echo ${script} | sed -e "s/^[0-9][0-9]-//" -e "s/\\.sh//")
  if [[ " ${ROLES[@]} " =~ " ${step} " ]]
  then
    echo "++ Executing '$script'"
    su vagrant -c "bash ./$script" || true
  else
    echo "-- Skipping '$script'"
  fi
done

su vagrant -c "bash -c \"[ -f ~/.bash_profile ] && echo '. ~/.profile' >> ~/.bash_profile\""
