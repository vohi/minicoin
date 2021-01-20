#!/bin/bash
if [[ $UID -eq 0 ]]
then
    if [[ -d /home/vagrant ]]
    then
        cd /home/vagrant
    elif [[ -d /Users/vagrant ]]
    then
        cd /Users/vagrant
    fi
    exec sudo -u vagrant -H /bin/bash "$0" "$@"
fi

. /minicoin/util/parse-opts.sh "$@"

if [ -f /minicoin/roles/coin-node/.hosts ]
then
    echo "Adding coin hosts"
    sudo bash -c "cat /minicoin/roles/coin-node/.hosts >> /etc/hosts"
fi

cd coin/provisioning
if [ $? -gt 0 ]
then
    >&2 echo "Can't find coin scripts"
    exit 1
fi


echo "Provisioning with template $PARAM_template as $(whoami)"
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

error_count=0
for script in ${SCRIPTS[@]}; do
    [ -e "$script" ] || continue
    step=$(echo ${script} | sed -e "s/^[0-9][0-9]-//" -e "s/\\.sh//")
 
    if [[ " ${SKIPLIST[@]} " =~ " ${step} " ]] && [[ ! " ${RUNLIST[@]} " =~ " ${step} " ]]
    then
        echo "-- Skipping '$script'"
        continue
    fi

    echo "++ Executing '$script'"
    output="$(bash ./$script 2>&1)"
    if [ $? -eq 0 ]
    then
        [[ $script == "99-version.sh" ]] && echo "$output"
        echo "   Success"
    else
        error_count=$(( $error_count+1 ))
        >&2 echo "   FAIL ($script)"
        >&2 echo "$output"
    fi
done

## various work arounds for bad provisioning
# some PATHS are written to .profile, others to .bash_profile,
# and bash won't run .profile if there is a .bash_profile
if [ -f ~/.bash_profile ]
then
    [ -f ~/.profile ] && echo '. ~/.profile' >> ~/.bash_profile || true
    . ~/.bash_profile
    . ~/.bashrc
fi
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

exit $error_count
