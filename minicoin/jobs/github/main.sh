#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

if [ -z $JOBDIR ]
then
  >&2 echo "Error: JOBDIR not set!"
  exit 1
fi

scriptdir="$(pwd)/$(dirname $0)"
scriptfile=$scriptdir/$PARAM_script

shellcmd="${PARAM_shell//{0\}/$scriptfile}"

echo "Running $PARAM_script from $scriptdir through $PARAM_shell"
ln -s -f $JOBDIR source
rm -rf build
$shellcmd
