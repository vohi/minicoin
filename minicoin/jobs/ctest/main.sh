#!/usr/bin/env bash
. /opt/minicoin/util/parse-opts.sh "$@"

if [ -z $JOBDIR ]
then
  >&2 echo "Error: path to host clone of Qt is required!"
  exit 1
fi

if [ ! -z $PARAM_build ]
then
    cd $PARAM_build
else
    cd /
    find_build=1
fi

IFS='/' read -ra SEGMENTS <<< "$JOBDIR"
for segment in "${SEGMENTS[@]}"; do
    [ -z $segment ] && continue

    if [ ! -z $find_build ]
    then
        if [ -z $PARAM_build ]
        then
            buildsegment=$segment-build
        else
            buildsegment=$PARAM_build
        fi

        if [ -d "$HOME/$buildsegment" ]
        then
            find_build=
            cd "$HOME/$buildsegment"
            continue
        fi
    fi

    cd $segment 2> /dev/null
done

echo "Running ctest ${PASSTHROUGH[@]} in $PWD"
ctest ${PASSTHROUGH[@]}
