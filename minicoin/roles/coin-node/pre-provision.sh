#!/bin/bash
cd $(dirname "$0")

rm -rf coin

if [[ ! -z $COIN_ROOT ]]
then
    cp -r $COIN_ROOT coin
else
    echo "COIN_ROOT not set, cloning from upstream"
    git clone --single-branch --branch dev --depth 1 git://code.qt.io/qt/qt5.git

    mv qt5/coin coin
    rm -rf qt5
fi

# A VM won't be able to resolve internal hostnames even if the minicoin host can
# so gather the host information now and so that the provisioning script can add
# entries to /etc/hosts
hosts=(ci-files01-hki.intra.qt.io)
for host in ${hosts[@]}
do
    hostip=$(dig ci-files01-hki.intra.qt.io +short)
    [ -z $hostip ] && >&2 echo "Can't resolve IP address of host '$host' - provisioning might fail"
    echo "$hostip     $host" >> coin/hosts
done
