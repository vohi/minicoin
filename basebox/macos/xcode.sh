#!/bin/bash

clang --version 2>&1 && exit 0

sudo xcode-select --install 2>&1

printf "Waiting for command line tools to be installed"
error=1
while [ ! $error -eq 0 ]
do
    printf "."
    sleep 5
    clang --version 2>&1 > /dev/null
    error=$?
done
printf "\n"

clang --version
exit 0
