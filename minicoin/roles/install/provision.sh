#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

if [[ $(uname) =~ "Darwin" ]]
then
    command="brew install"
else
    . /etc/os-release
    distro=${ID}${VERSION_ID}
    case $distro in
        ubuntu*)
            command="apt-get -qq -y install"
        ;;

        centos*)
            command="yum install -y"
        ;;

    esac
fi

packages=( ${PARAM_packages:-$PARAM_install} )

for package in "${packages[@]}"
do
    echo "Installing $package using $command"
    $command $package
done
