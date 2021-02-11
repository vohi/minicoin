#!/bin/bash

installed=$(sw_vers | grep "ProductVersion")

if [[ ! $MINICOIN_OS_UPGRADE ]]
then
    echo "MINICOIN_OS_UPGRADE not set, will try latest"
else
    if [[ $installed == $MINICOIN_OS_UPGRADE ]]
    then
        echo "Version $MINICOIN_OS_UPGRADE is already installed"
        exit 0
    fi
fi

installer="$(find /Applications -name startosinstall)"
if [[ ! $installer ]]
then
    if [[ $MINICOIN_OS_UPGRADE ]]
    then
        echo "Checking for OS upgrade to version $MINICOIN_OS_UPGRADE"
        upgrade_check="--full-installer-version $MINICOIN_OS_UPGRADE"
    fi
    sudo softwareupdate --fetch-full-installer $upgrade_check 2>&1 | sudo tee /var/log/minicoin_softwareupdate.log
fi

if (grep "Install failed with error: Update not found" /var/log/minicoin_softwareupdate.log)
then
    echo "New OS version not available, currently installed: $installed"
    exit 1
fi

installer="$(find /Applications -name startosinstall)"
if [[ ! $installer ]]
then
    >&2 echo "No installer found, aborting"
    exit 1
fi

echo "Running installer: ${installer}"

echo "vagrant" | "${installer}" --agreetolicense --forcequitapps --stdinpass --user vagrant --nointeraction --rebootdelay 60
sleep 30

echo "OS upgrade complete, system will reboot"
exit 0
