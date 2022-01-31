#!/bin/bash

for cloud in "aws" "azure"
do
    if [ -d "$cloud/$1" ]
    then
        cd "$cloud/$1"
        tar cvzf "../../$1-$cloud.box" metadata.json Vagrantfile info.json
        cd -
    fi
done
