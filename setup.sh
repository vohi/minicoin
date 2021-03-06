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
        sudo apt-get update > /dev/null
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

# recommended versions
vbox_version_good=6.1.16
vagrant_version_good=2.2.14
mutagen_version_good=0.11.8

cd /tmp

vagrant_version=`vagrant --version 2> /dev/null`
vbox_version=`VBoxManage --version 2> /dev/null`
if [ $? -gt 0 ]
then
    echo "vagrant not found, installing..."

    if [ -z $vbox_version ]
    then
        echo "VirtualBox not found, installing first..."
        $install_command virtualbox
        default_dhcp=$(VBoxManage list dhcpservers | grep NetworkName: | awk '{print $2}')
        VBoxManage dhcpserver remove --netname ${default_dhcp} # workaround https://github.com/hashicorp/vagrant/issues/3083
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
    curl -L -O "https://download.virtualbox.org/virtualbox/${vbox_version}/${filename}"
    sudo VBoxManage extpack install "${filename}"

    case $distro in
        ubuntu*|neon*)
            $install_command ruby-dev
            curl -L -O https://releases.hashicorp.com/vagrant/${vagrant_version_good}/vagrant_${vagrant_version_good}_`arch`.deb
            $install_command ./vagrant_${vagrant_version_good}_`arch`.deb
            ;;
        *)
            $install_command vagrant
            ;;
    esac
    if [ $? -eq 0 ]
    then
        echo "Installing winrm Ruby gem..."
        sudo gem install winrm
        sudo gem install winrm-elevated
    fi
    vagrant_version=`vagrant --version | awk '{print $2}'`
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
        filename="mutagen_linux_amd64_v${mutagen_version_good}.tar.gz"
        sudo curl -O -L https://github.com/mutagen-io/mutagen/releases/download/v${mutagen_version_good}/${filename}
        sudo mkdir -p /opt/mutagen
        sudo tar -xf "${filename}" -C /opt/mutagen
        [ $? -eq 0 ] && sudo ln -s /opt/mutagen/mutagen /usr/local/bin/mutagen
    fi
    mutagen_version=`mutagen version`
else
    echo "mutagen version ${mutagen_version} found!"
fi

cd - > /dev/null
if [ -d "/usr/local/bin" ]
then
    echo "Linking minicoin to /usr/local/bin"
    sudo ln -fs $PWD/minicoin/minicoin /usr/local/bin/minicoin
fi

minicoin update 2> /dev/null

printf "\nMinicoin set up!\n"
printf "%s: %s\n" "- vagrant version" "$vagrant_version"
[[ "${vagrant_version}" < "${vagrant_version_good}" ]] && echo "   You might need to upgrade to version ${vagrant_version_good}!"
printf "%s: %s\n" "- VirtualBox version" "$vbox_version"
[[ "${vbox_version}" < "${vbox_version_good}" ]] && echo "   You might need to upgrade to version ${vagrant_version_good}!"
printf "%s: %s\n" "- mutagen version" "$mutagen_version"
[[ "${mutagen_version}" < "${mutagen_version_good}" ]] && echo "   You might need to upgrade to version ${mutagen_version_good}!"
minicoin list

[[ -z $minicoin_key ]] && printf "\nNote: 'minicoin_key' not set, some boxes will not be available!\n"
