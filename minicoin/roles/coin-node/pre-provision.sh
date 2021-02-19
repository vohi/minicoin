#!/bin/bash
cd $(dirname "$0")

# A VM won't be able to resolve internal hostnames even if the minicoin host can
# so gather the host information now and so that the provisioning script can add
# entries to /etc/hosts
hosts=(ci-files01-hki.intra.qt.io)
echo "# internal hosts" > /tmp/.hosts
for host in ${hosts[@]}
do
    hostip=$(dig ci-files01-hki.intra.qt.io +short)
    if [ -z $hostip ]
    then
        >&2 echo "Can't resolve IP address of host '$host' - provisioning might fail"
    else
        echo "$hostip     $host" >> /tmp/.hosts
    fi
done

minicoin upload /tmp/.hosts .hosts $1
