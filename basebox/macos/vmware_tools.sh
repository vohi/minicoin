#!/bin/bash

# install the package copied over by the prepare script

error=1
retry=5
while [[ $error != 0 ]]
do
    sleep 20
    sudo installer -allowUntrusted -pkg vmware_tools.pkg -target /
    error=$?
    retry=$(( $retry-1 ))
    [[ $retry == 0 ]] && break
done

if [[ $error -gt 0 ]]
then
    >&2 echo "Failed to install VMware tools, do it manually"
else
    rm vmware_tools.pkg 
    sudo shutdown -r now
fi
