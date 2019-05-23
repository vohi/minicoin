#!/usr/bin/env bash
set +ex

if [[ $# < 2 ]]; then
  echo "Usage: $0 name folder"
  exit 1
fi

tar zcvf $1.box -Cvmware ./metadata.json "-C$2" .
vagrant box add $1.box --name vmware/$1 --provider vmware_desktop
