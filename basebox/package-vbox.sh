#!/usr/bin/env bash
set +ex

if [ $# -lt 1 ]; then
  echo "Export an existing VirtualBox machine to a box file"
  echo ""
  echo "Usage: $0 vm-name [boxname]"
  echo ""
  exit -1
fi

vmname="$1"
[[ ! -z "$2" ]] && boxname="$2" || boxname=${vmname/basebox/virtualbox}
boxfile="$boxname.box"

if [ -f "$boxfile" ]; then
  [ -f "$boxfile.old" ] && rm $boxfile.old
  mv $boxfile $boxfile".old"
fi

echo "Exporting VM '$vmname' to file '$boxfile' ..."

vagrant package --output $boxfile $vmname
error=$?

if [ $error != 0 ]
then
  echo "==> $1: Packaging failure!"
  if [ -f "$boxfile.old" ]
  then
    echo "==> $1: Restoring previous version"
    mv "$boxfile.old" "$boxfile"
  fi
  exit $error
fi

[ -f "$boxfile.old" ] && rm $boxfile.old
