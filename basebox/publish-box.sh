#!/usr/bin/env bash
set +ex

if [ $# -lt 2 ]; then
  echo "Publish a box file to the AWS 'tqtc-vagrant-boxes' S3 bucket" 
  echo ""
  echo "Usage: $0 boxfile aws|azure [private]"
  echo ""
  echo "Uses the AWS and Azure cli clients. Make sure access credentials are configured."
  echo "The box file will be world-readable, so make sure it doesn't contain any secrets."
  exit -1
fi

blobname=$(basename $1)
private=
if [[ "$3" != "" ]]; then
  private="$3/"
fi

if [[ "$2" == "aws" ]]; then
  aws s3 cp $1 s3://tqtc-vagrant-boxes/tqtc/$private$blobname
  aws s3api put-object-acl --bucket tqtc-vagrant-boxes --key tqtc/$private$blobname --acl public-read
elif [[ "$2" == "azure" ]]; then
  az storage blob upload -f $1 -n tqtc/$private$blobname -c \$web --account-name tqtcvagrantboxes
else
  echo "Unknown cloud storage provider '$2'"
fi

