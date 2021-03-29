#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

set -e

if [ -z $JOBDIR ]
then
  >&2 echo "Error: No job directory specified!"
  exit 1
fi

projectname="$(basename $JOBDIR)"
bindir="${PARAM_bindir:-${projectname}-build}"
[ -d $bindir ] && cd $bindir

IFS=$'\n' exefiles=( `find . -type f -perm -u=x -name ${PARAM_exe:-'*'} ! -name '*.out' ! -name '*.bin'` )

if [ ${#exefiles[@]} -lt 1 ]
then
    >&2 echo "No match executable found in $PWD"
    exit 2
fi

if [ ${#exefiles[@]} -gt 1 ]
then
    >&2 echo "Multiple candidates found, specify via --exe:"
    for candidate in ${exefiles[@]}
    do
        >&2 echo "- ${candidate}"
    done
    exit 2
fi
exefile=${exefiles[0]}

eval "args=(${PARAM_args})"
$exefile ${args[@]}
