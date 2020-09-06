#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

if [[ $(uname) =~ "Darwin" ]]
then
    account_path="$HOME/Library/Application Support/Qt"
else
    account_path="$HOME/.local/share/Qt"
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

cmake -DINSTALL_ROOT=Qt "$@" -P $jobpath/install-online.cmake

if [ ! -d "Qt/6.0.0" ]
then
    >&2 echo "Installation failed, aborting"
    exit 4
fi

cd Qt/6.0.0

platforms=$(find . -maxdepth 1 -mindepth 1 -type d)
for p in "$platforms"
do
    cd $p
done

export LD_LIBRARY_PATH=$PWD/lib
export DISPLAY=:0
bin/qtdiag
bin/uic --version
bin/moc --version
bin/qmake --version
