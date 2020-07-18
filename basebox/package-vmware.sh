#!/usr/bin/env bash
set +ex

if [[ $# < 1 ]]
then
  echo "Usage: $0 folder [boxname]"
  exit 1
fi

machine="$1"
if [ ! -d "$machine" ]
then
  machine="$HOME/Virtual Machines.localized/$machine.vmwarevm"
fi

if [ ! -d "$machine" ]
then
  echo "No Virtual Machine found at '$machine'"
  exit 2
fi

vmname=$(basename "$1")
[ -z "$2" ] && boxname="$vmname" || boxname="$2"
boxfile="$boxname.box"

echo "Exporting VM '$vmname' from '$machine' to file '$boxfile' ..."

rm "$1"/*.log 2> /dev/null
rm "$1"/*.plist 2> /dev/null
rm -rf "$1"/*.lck 2> /dev/null
rm -rf "$1"/Applications 2> /dev/null
rm -rf "$1"/appListCache 2> /dev/null

tar zcvf "$boxfile" -Cvmware ./metadata.json "-C$machine" .
