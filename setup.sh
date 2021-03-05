#!/bin/bash

distro=`uname`

if [ $distro != "Darwin" ]
then
    if [ $EUID != 0 ]
    then
        >&2 echo "This script installs software and needs to be run as sudo!"
        exit 1
    fi

    . /etc/os-release
    distro=${ID}${VERSION_ID}
else
    if [ $EUID == 0 ]
    then
        >&2 echo "This script uses Homebrew to install software, and can not be run as root!"
        exit 1
    fi
fi

case $distro in
    ubuntu|neon*)
        apt-get update
        install_command="apt-get -qq -y install"
        ;;
    Darwin*)
        install_command="brew install"
        ;;
    *)
        print "Don't know how to install packages on $distro."
        exit 1
        ;;
esac

cd /tmp

vagrant_version=`vagrant --version 2> /dev/null`
if [ $? -gt 0 ]
then
    echo "vagrant not found, installing..."

    vbox_version=`VBoxManage --version 2> /dev/null`
    if [ $? -gt 0 ]
    then
        echo "VirtualBox not found, installing first..."
        $install_command virtualbox
        vbox_version=`VBoxManage --version`
    else
        echo "VirtualBox version ${vbox_version} found!"
    fi
    regex='([0-9]+\.[0-9]+\.[0-9]+).*'
    if [[ $vbox_version =~ $regex ]]
    then
        vbox_version=${BASH_REMATCH[1]}
    fi
    echo "Installing VirtualBox extension pack. This requires sudo, your password may be required"
    filename="Oracle_VM_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack"
    curl "https://download.virtualbox.org/virtualbox/${vbox_version}/${filename}" -o "${filename}"
    sudo VBoxManage extpack install "${filename}"

    $install_command vagrant
    if [ $? -eq 0 ]
    then
        echo "Installing winrm Ruby gem..."
        gem install winrm
    fi
else
    echo "vagrant version ${vagrant_version} found!"
fi

mutagen_version=`mutagen version 2> /dev/null`
if [ $? -gt 0 ]
then
    echo "Mutagen not found, installing"
    if [ $distro == "Darwin" ]
    then
        brew install mutagen-io/mutagen/mutagen
    else
        mutagen_version="0.11.8"
        filename="mutagen_linux_amd64_v${mutagen_version}.tar.gz"
        curl https://github.com/mutagen-io/mutagen/releases/download/v${mutagen_version}/${filename} -o "${filename}"
        mkdir -p /opt/mutagen
        tar -xf "${filename}" -C /opt/mutagen
        [ $? -eq 0 ] && ln -s /opt/mutagen/mutagen /usr/local/bin/mutagen
    fi
else
    echo "mutagen version ${mutage_version} found!"
fi

cd - > /dev/null
if [ -d "/usr/local/bin" ]
then
    echo "Linking minicoin to /usr/local/bin"
    ln -fs $PWD/minicoin/minicoin /usr/local/bin/minicoin
fi

minicoin update

echo
echo "Minicoin set up!"
minicoin list
