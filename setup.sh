#!/bin/bash

distro=`uname`

if [ $EUID == 0 ]
then
    >&2 echo "This script can not be run as root (it will ask for privileges when needed)!"
    exit 1
fi

if [ $distro != "Darwin" ]
then
    . /etc/os-release
    distro=${ID}${VERSION_ID}
fi

case $distro in
    ubuntu*|neon*)
        sudo apt-get update
        install_command="sudo apt-get -qq -y install"
        ;;
    Darwin*)
        install_command="brew install"
        ;;
    *)
        echo "Don't know how to install packages on $distro.\n"
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

    $install_command ruby-dev
    $install_command vagrant
    if [ $? -eq 0 ]
    then
        echo "Installing winrm Ruby gem..."
        sudo gem install winrm
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
        sudo curl -L https://github.com/mutagen-io/mutagen/releases/download/v${mutagen_version}/${filename} -o "${filename}"
        sudo mkdir -p /opt/mutagen
        sudo tar -xf "${filename}" -C /opt/mutagen
        [ $? -eq 0 ] && sudo ln -s /opt/mutagen/mutagen /usr/local/bin/mutagen
    fi
else
    echo "mutagen version ${mutage_version} found!"
fi

cd - > /dev/null
if [ -d "/usr/local/bin" ]
then
    echo "Linking minicoin to /usr/local/bin"
    sudo ln -fs $PWD/minicoin/minicoin /usr/local/bin/minicoin
fi

minicoin update

echo
echo "Minicoin set up!"
minicoin list

[[ -z $minicoin_key ]] && printf "\nNote: 'minicoin_key' not set, some boxes will not be available!\n"
