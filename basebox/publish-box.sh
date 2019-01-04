#!/usr/bin/env bash
set +ex

if [ $# -lt 1 ]; then
  echo "Publish a box file to the AWS 'tqtc-vagrant-boxes' S3 bucket" 
  echo ""
  echo "Usage: $0 boxfile"
  echo ""
  echo "Uses the AWS cli client. Make sure access credentials are configured."
  echo "The box file will be world-readable, so make sure it doesn't contain any secrets."
  exit -1
fi
aws s3 cp $1 s3://tqtc-vagrant-boxes/tqtc/$1
aws s3api put-object-acl --bucket tqtc-vagrant-boxes --key tqtc/$1 --acl public-read
