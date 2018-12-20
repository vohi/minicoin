#!/usr/bin/env bash
set +ex

if [ $# -lt 1 ]; then

  echo "Export an existing virtual machine to a box file and register with vagrant"
  echo ""
  echo "Usage: $0 vm-name [boxname]"
  echo ""
  exit -1
fi

vmname=$1

if [ -z "$2" ]; then
  boxbase=$vmname
else
  boxbase=$2
fi

boxfile=$boxbase.box
clear_backup=false

if [ -f $boxfile ]; then
  if [ -f $boxfile.old ]; then
    rm $boxfile.old
  fi
  mv $boxfile $boxfile".old"
  clear_backup=true
fi

echo "Exporting VM '$vmname' to file '$boxfile' and adding to vagrant as 'tqtc/$boxbase'..."

vagrant package --base $vmname --output $boxfile $boxbase
error=$?

if [[ error != 0 ]]; then
  if [[ "$clear_backup" = true ]]; then
    echo "==> $1: Packaging failure, restoring previous version"
    mv $boxfile.old $boxfile
  fi
  exit $error
fi

vagrant box add --name tqtc/$boxbase $boxfile
error=$?

if [[ error != 0 ]]; then
  echo "==> $1: New box exported, but failed to add to vagrant"
fi

if [[ "$clear_backup" = true ]]; then
  rm $boxfile.old
fi
