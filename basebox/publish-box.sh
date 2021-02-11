#!/usr/bin/env bash
set +ex

if [ $# -lt 2 ]
then
    echo "Publish box files to cloud storage" 
    echo ""
    echo "Usage: $0 box.json aws|azure"
    echo ""
    echo "Uses the AWS and Azure cli clients. Make sure access credentials are configured."
    echo "The box files will be world-readable, so make sure it doesn't contain any secrets."
    exit -1
fi

metafile="$1"
metafilename=$(basename ${metafile})

if [ ! -f "${metafile}" ]
then
    >&2 echo "File not found: ${metafile}"
    exit 1
fi

meta=$(cat "${metafile}")
meta=$(echo "${meta}" | sed "s/file:\/\/\/tmp/https:\/\/tqtcvagrantboxes.z16.web.core.windows.net\/tqtc\/${minicoin_key}/g")

metafile_up="/tmp/${metafilename}"
echo "${meta}" > "${metafile_up}"
echo "Generated ${metafile}:"
cat "${metafile_up}"

function to_aws()
{
    if [ aws s3 cp "$1" s3://tqtc-vagrant-boxes/tqtc/${minicoin_key}/${2} ]
    then
        aws s3api put-object-acl --bucket tqtc-vagrant-boxes --key tqtc/${minicoin_key}/${2} --acl public-read
    fi
}

function to_azure()
{
    exists=$(az storage blob exists -n tqtc/${minicoin_key}/${2} -c \$web --account-name tqtcvagrantboxes -o tsv 2> /dev/null)
    if [ $exists == "True" ]
    then
        >&2 echo "The blob ${2} already exists. Press any key to skip!"
        read -t 5 -n 1
        if [ $? = 0 ]
        then
            echo " -> skipping ${2}"
            return
        fi
    fi

    echo " -> Uploading ${2}"
    az storage blob upload -f "$1" -n tqtc/${minicoin_key}/${2} -c \$web --account-name tqtcvagrantboxes
}

files=$(ruby box-files.rb ${metafile})
files=( ${files[@]} "${metafile_up}")

error=0
for file in ${files[@]}
do
    echo "Uploading '${file} to ${2}...."
    to_${2} "${file}" "${file#/tmp/}"
    if [ $error -gt 0 ]
    then
        >&2 echo "Error uploading box '${file}' to ${2}"
        exit 2
    fi
done
