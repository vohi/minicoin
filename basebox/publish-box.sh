#!/usr/bin/env bash
set +ex

if [ $# -lt 2 ]
then
  echo "Publish a box file to the AWS 'tqtc-vagrant-boxes' S3 bucket" 
  echo ""
  echo "Usage: $0 boxfile aws|azure [private] [virtualbox|vmware_desktop|azure]"
  echo ""
  echo "Uses the AWS and Azure cli clients. Make sure access credentials are configured."
  echo "The box file will be world-readable, so make sure it doesn't contain any secrets."
  exit -1
fi

blobname=$(basename $1)
private=
if [ "$3" != "" ]
then
  private="$3/"
fi
provider=
[ ! -z "$4" ] && provider="$4/"

metafile=${blobname%-*} # strip version number
metafile=${metafile%-*} # and provider from filename
metafile="../minicoin/boxes/tqtc/$metafile.json"
if [ -f "$metafile" ] && [ ! -z "$private" ]
then
  metafilename="$(basename $metafile)"

  meta=$(cat "$metafile")
  meta=$(echo "$meta" | sed "s/\$server/tqtcvagrantboxes.z16.web.core.windows.net\/tqtc/g")
  meta=$(echo "$meta" | sed "s/\$minicoin_key/${private}g")

  metafile="/tmp/$metafilename"
  echo "$meta" > "$metafile"
else
  >&2 echo "No metafile found at '$metafile'"
  metafile=
fi

error=0
if [ "$2" == "aws" ]
then
  if [ -f "$metafile" ]
  then
    if [ aws s3 cp "$metafile" s3://tqtc-vagrant-boxes/tqtc/$private$blobname ]
    then
      aws s3api put-object-acl --bucket tqtc-vagrant-boxes --key tqtc/$private$metafilename --acl public-read
    fi
    error=$?
    rm "$metafile"
  fi
  if [ $error -eq 0 ]
  then
    if [ aws s3 cp "$1" s3://tqtc-vagrant-boxes/tqtc/$private$blobname ]
    then
      aws s3api put-object-acl --bucket tqtc-vagrant-boxes --key tqtc/$private$provider$blobname --acl public-read
    fi
    error=$?
  else
    >&2 echo "Metafile upload error - aborting"
  fi
elif [ "$2" == "azure" ]
then
  if [ -f "$metafile" ]
  then
    az storage blob upload -f "$metafile" -n tqtc/$private$metafilename -c \$web --account-name tqtcvagrantboxes
    error=$?
    rm "$metafile"
  fi
  if [ $error -eq 0 ]
  then
    az storage blob upload -f "$1" -n tqtc/$private$provider$blobname -c \$web --account-name tqtcvagrantboxes
    error=$?
  else
    >&2 echo "Metafile upload error - aborting"
  fi
else
  echo "Unknown cloud storage provider '$2'"
  exit 1
fi

[ $error -eq 0 ] || >&2 echo "Failed to upload to $2"
exit $error
