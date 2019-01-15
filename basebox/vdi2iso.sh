#!/usr/bin/env bash
echo "Cloning $1.vdi to a fixed-size medium"
VBoxManage clonemedium $1.vdi $1.dmg --variant Fixed
VBoxManage closemedium $1.dmg
echo "Attaching $1.dmg"
vol=$(hdiutil attach -section 0x1000 $1.dmg | grep "Volumes" | awk '{print $NF}')
echo "Writing $vol to $1.iso"
hdiutil makehybrid -iso -joliet -o $1.iso $vol
ls -la $1.iso
echo "Cleaning up..."
hdiutil detach $vol
rm $1.dmg
