#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

if [[ $(uname) =~ "Darwin" ]]
then
    account_path="$HOME/Library/Application Support/Qt"
else
    account_path="$HOME/.local/share/Qt"

    # make sure we are logged in
    XAUTHORITY=$XAUTH_FILE sudo xdotool type "vagrant"
    XAUTHORITY=$XAUTH_FILE sudo xdotool key --clearmodifiers Return
fi

jobpath="$(dirname $0)"
if [ -f "$jobpath/qtaccount.ini" ]
then
    if [ ! -f "$account_path" ]
    then
        echo "Installing qtaccount.ini file from $jobpath"
        [ -d "$account_path" ] || mkdir -p "$account_path"
        cp "$jobpath/qtaccount.ini" "$account_path/qtaccount.ini"
    fi
else
    echo "qtaccount.ini file not found in $jobpath, aborting"
    exit 3
fi

INSTALL_ROOT=${PARAM_install_root:-"Qt"}

cmake -DINSTALL_ROOT=${INSTALL_ROOT} -DPACKAGE=$PARAM_package -P $jobpath/install-online.cmake
if [ $? -gt 0 ]
then
    >&2 echo "Installation failed, aborting"
    exit 4
fi

cd ${INSTALL_ROOT}

qtinstall=$(find . -wholename */bin/moc | sort -z | head -n 1)
if [[ -z $qtinstall ]]
then
    >&2 echo "moc not found, installation failed!"
    exit 5
fi

qtinstall=$(dirname $(dirname ${qtinstall}))

cd ${qtinstall}
echo "Using Qt in $PWD"
export LD_LIBRARY_PATH=$PWD/lib

bin/qtdiag
bin/uic --version
bin/moc --version
bin/qmake -query
