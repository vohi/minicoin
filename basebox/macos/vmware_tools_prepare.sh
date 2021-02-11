#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob nocaseglob

iso_image="/tmp/darwin.iso"
volume="/Volumes/VMware Tools"

# mount the uploaded iso image and install the package, then unmount
hdiutil mount "$iso_image"
package=$(find "$volume" -wholename "*/Install*/*.pkg")
cp "$package" ~/vmware_tools.pkg
hdiutil unmount "$volume"
rm "$iso_image"
