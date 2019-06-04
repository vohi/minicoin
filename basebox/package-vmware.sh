#!/usr/bin/env bash
set +ex

if [[ $# < 2 ]]; then
  echo "Usage: $0 name folder"
  exit 1
fi

rm "$2"/*.log
rm "$2"/*.plist

tar zcvf $1.box -Cvmware ./metadata.json "-C$2" .
