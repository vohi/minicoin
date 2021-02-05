#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh $HOME "$@"

if [[ $(uname) =~ "Darwin" ]]
then
    distro="darwin"
else
    . /etc/os-release
    distro=${ID}${VERSION_ID}
fi

case $distro in
    ubuntu*)
        apt-get update
        command="apt-get -qq -y install"
    ;;

    centos*)
        yum update -y
        command="yum install -y"
    ;;

    darwin*)
        su vagrant -c "brew update"
        command="brew install"
    ;;
esac

packages=( ${PARAM_packages[@]:-${PARAM_install[@]}} )

echo "Installing '${packages[@]}' using '$command'"
for package in "${packages[@]}"
do
    echo "Installing '$package'"
    if [[ $distro == "darwin" ]]
    then
        su vagrant -c "$command $package"
    else
        $command $package
    fi
done
