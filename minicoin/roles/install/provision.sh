#!/usr/bin/env bash
. /opt/minicoin/util/parse-opts.sh $HOME "$@"

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
        command="apt-get ${PARAM_options:-"-y -qq"} install"
    ;;

    centos*)
        yum update -y
        command="yum install ${PARAM_options:-"-y -qq"}"
    ;;

    opensuse*)
        command="zypper --non-interactive --quiet install -y ${PARAM_options}"
    ;;

    darwin*)
        su vagrant -c "brew update"
        command="brew install ${PARAM_options:-"--quiet"}"
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
