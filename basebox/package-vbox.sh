#!/usr/bin/env bash
set +ex

if [ $# -lt 1 ]; then

  echo "Export an existing VirtualBox machine to a box file"
  echo ""
  echo "Usage: $0 vm-name [boxname]"
  echo ""
  exit -1
fi

vmname=$1

[[ ! -z "$2" ]] && boxbase=$2 || boxbase=$vmname

clear_backup=false

boxfile=$boxbase.box

if [ -f $boxfile ]; then
  if [ -f $boxfile.old ]; then
    rm $boxfile.old
  fi
  mv $boxfile $boxfile".old"
  clear_backup=true
fi

echo "Exporting VM '$vmname' to file '$boxfile' and adding to vagrant as '$boxbase'..."

vagrant package --base $vmname --output $boxfile $boxbase
error=$?

if [[ $error != 0 ]]; then
  echo "==> $1: Packaging failure!"
  if [[ "$clear_backup" = true ]]; then
    echo "==> $1: Restoring previous version"
    mv $boxfile.old $boxfile
  fi
  exit $error
fi

error=$?

if [[ "$clear_backup" = true ]]; then
  rm $boxfile.old
fi
