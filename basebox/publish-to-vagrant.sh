#!/bin/bash

if [ $# -eq 0 ]
then
    >&2 echo "Usage: $0 version"
    exit
fi

version=${1:-"0.0.1"}

for os in "windows" "macos" "linux"
do
    ./package-cloud.sh "$os"
    for cloud in "azure" "aws"
    do
        if [ -f "${os}-${cloud}.box" ]
        then
            checksum=$(sha256sum "${os}-${cloud}.box" | cut -d ' ' -f1)
            vagrant cloud publish --force --no-private --checksum ${checksum} --checksum-type sha256 "minicoin/${os}-cloud" "${version}" "${cloud}" "${os}-${cloud}.box"
        fi
    done
done
