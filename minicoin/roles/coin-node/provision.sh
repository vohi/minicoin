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

RUNLIST=${PARAM_runlist[@]}
SKIPLIST=${PARAM_skiplist[@]}

[[ -z "$RUNLIST" ]] && RUNLIST=(
    enable-repos
    apt zypperpackages install-packages
    cmake install-cmake
    )

[[ -z "$SKIPLIST" ]] && SKIPLIST=(
    install_telegraf
    systemsetup
    emsdk
    qemu install_QemuGA
    qnx660 qnx700
    squish squish-coco
    yocto yocto_ssh_configurations
    android_linux openssl_for_android_linux
    docker fix_msns_docker_resolution
    )

for script in ${SCRIPTS[@]}; do
    [ -e "$script" ] || continue
    step=$(echo ${script} | sed -e "s/^[0-9][0-9]-//" -e "s/\\.sh//")
    skip=0
    [[ " ${SKIPLIST[@]} " =~ " ${step} " ]] && skip=1
    [[ " ${RUNLIST[@]} " =~ " ${step} " ]] && skip=0

    if [[ $skip -gt 0 ]]
    then
        echo "-- Skipping '$script'"
        continue
    fi

    echo "++ Executing '$script'"
    su vagrant -c "bash ./$script" || true
done

su vagrant -c "bash -c \"[ -f ~/.bash_profile ] && echo '. ~/.profile' >> ~/.bash_profile\" || true"
