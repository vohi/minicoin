#!/usr/bin/env bash
set +ex

if [ $# -lt 1 ]; then

  echo "Export an existing virtual machine to a box file and register with vagrant"
  echo ""
  echo "Usage: $0 vm-name [boxname] [vagrantfile]"
  echo ""
  exit -1
fi

vmname=$1

[[ ! -z "$2" ]] && boxbase=$2 || boxbase=$vmname
[[ ! -z "$3" ]] && vagrantfile="--vagrantfile $3"

meta_provider="virtualbox"
meta_version=
metafile="../minicoin/boxes/tqtc/$boxbase.json"
if [[ ! -f $metafile ]]; then
  read -p "Generate a metadata file for $boxbase? (yes/no): " meta_generate
    if [[ $meta_generate == "yes" ]]; then
    read -p "Description: " meta_description
    read -p "Version (x.y.z): " meta_version

    template=$(cat template.json)
    template=${template//\$name/$boxbase}
    template=${template//\$description/$meta_description}
    template=${template//\$version/$meta_version}
    template=${template//\$provider/$meta_provider}

    printf "%s\n" "$template" > $metafile
  fi
else
  echo "Metadata file exists, appending new version"
  read -p "Version (x.y.z): " meta_version
  template=$(tail -n +5 template.json)
  template=${template//\$name/$boxbase}
  template=${template//\$version/$meta_version}
  template=${template//\$provider/$meta_provider}

  previous=$(cat $metafile)
  endmarker="
        }
    ]
}"
  newend="
        },
"

  previous=${previous/$endmarker/$newend$template}
  printf "%s\n" "$previous" > $metafile
fi

clear_backup=false

if [[ ! -z $meta_version ]]; then
  boxfile=$boxbase-$meta_version.box
else
  boxfile=$boxbase.box
fi

if [ -f $boxfile ]; then
  if [ -f $boxfile.old ]; then
    rm $boxfile.old
  fi
  mv $boxfile $boxfile".old"
  clear_backup=true
fi

echo "Exporting VM '$vmname' to file '$boxfile' and adding to vagrant as '$boxbase'..."
if [[ $vagrantfile != "" ]]; then
  echo "Including vagrantfile $3"
fi

vagrant package --base $vmname --output $boxfile $vagrantfile $boxbase
error=$?

if [[ $error != 0 ]]; then
  echo "==> $1: Packaging failure!"
  if [[ "$clear_backup" = true ]]; then
    echo "==> $1: Restoring previous version"
    mv $boxfile.old $boxfile
  fi
  exit $error
fi

vagrant box add --name $boxbase $boxfile
error=$?

if [[ $error != 0 ]]; then
  echo "==> $1: New box exported, but failed to add to vagrant"
fi

if [[ "$clear_backup" = true ]]; then
  rm $boxfile.old
fi
