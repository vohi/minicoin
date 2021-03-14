#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

command -v cmake &> /dev/null || install_cmake=1

if [[ $(uname) =~ "Darwin" ]]
then
    [ $install_cmake -gt 0 ] && brew install cmake
    account_path="$HOME/Library/Application Support/Qt"
else
    if [ $install_cmake -gt 0 ]
    then
        cd /tmp
        wget -q https://cmake.org/files/LatestRelease/cmake-3.19.6-Linux-x86_64.sh
        chmod +x cmake-3.19.6-Linux-x86_64.sh
        sudo ./cmake-3.19.6-Linux-x86_64.sh --prefix=/usr/local/ --skip-license
        cd -
    fi
    account_path="$HOME/.local/share/Qt"

    # make sure we are logged in
    if command -v xdotool &> /dev/null
    then
        XAUTHORITY=$XAUTH_FILE sudo xdotool type "vagrant"
        XAUTHORITY=$XAUTH_FILE sudo xdotool key --clearmodifiers Return
    fi
fi

jobpath="$(dirname $0)"
if [ -f "qtaccount.ini" ]
then
    if [ ! -f "$account_path" ]
    then
        echo "Installing qtaccount.ini file from $PWD"
        [ -d "$account_path" ] || mkdir -p "$account_path"
        cp "qtaccount.ini" "$account_path/qtaccount.ini"
    fi
else
    echo "qtaccount.ini file not found in $PWD, aborting"
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

[ -f bin/qmake ] && ln -sf $PWD/bin/qmake $HOME/qmake
[ -f bin/qt-cmake ] && ln -sf $PWD/bin/qt-cmake $HOME/qt-cmake
