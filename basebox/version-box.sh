#!/usr/bin/env bash
set +ex

if [ $# -lt 1 ]; then
  echo "Generate versioning metadata for a boxfile"
  echo ""
  echo "Usage: $0 boxfile [provider=virtualbox]" 
  echo ""
  exit -1
fi

boxfile=$1
boxbase=$(basename -s .box $boxfile)

meta_provider=${2:-virtualbox}
meta_version=
metafile="../minicoin/boxes/tqtc/$boxbase.json"
read -p "Version (x.y.z): " meta_version

if [[ ! -f $metafile ]]; then
  echo "Generating a metadata file for $boxbase"
  read -p "Description: " meta_description

  template=$(cat template.json)
  template=${template//\$description/$meta_description}
  template=${template//\$name/$boxbase}
  template=${template//\$version/$meta_version}
  template=${template//\$provider/$meta_provider}

  printf "%s\n" "$template" > $metafile
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

mv $boxfile $boxbase-$meta_version.box
