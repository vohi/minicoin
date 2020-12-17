if [[ $UID -eq 0 ]]
then
    cd /home/vagrant
    exec su vagrant $0 -- $@
fi

. /minicoin/util/parse-opts.sh "$@"

cd /minicoin/roles/coin-node/coin
if [ $? -gt 0 ]
then
    >&2 echo "Can't find coin scripts"
    exit 1
fi

sudo bash -c "cat hosts >> /etc/hosts"

echo "Provisioning with template $PARAM_template"
cd provisioning/$PARAM_template

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
    # systemsetup
    emsdk
    qemu install_QemuGA
    qnx660 qnx700 qnx_700
    integrity
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
    output=$(bash ./$script 2>&1)
    if [ $? -eq 0 ]
    then
        echo "   Success"
    else
        >&2 echo "   FAIL"
        >&2 echo $output
    fi
done

## various work arounds for bad provisioning
# some PATHS are written to .profile, others to .bash_profile,
# and bash won't run .profile if there is a .bash_profile
[ -f ~/.profile ] && echo '. ~/.profile' >> ~/.bash_profile || true
. ~/.bash_profile
. ~/.bashrc
# some things are installed as sudo, so the vagrant user can't run them
IFS=":"; for p in $PATH
do
    while true
    do
        sudo chmod 755 $p &> /dev/null || true
        p=$(dirname $p)
        [[ $p == "/" ]] && break
    done
done
