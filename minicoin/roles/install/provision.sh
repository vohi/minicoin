#!/usr/bin/env bash
. /opt/minicoin/util/install_helper.sh
. /opt/minicoin/util/parse-opts.sh $HOME "$@"

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
