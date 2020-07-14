
disk="$1"
vdi="${disk/vmdk/vdi}"
if [[ "$disk" =~ ".vmdk" ]]
then
    echo "Cloning VMDK to '$vdi'"
    VBoxManage clonemedium disk --format VDI "$disk" "$vdi"
fi

echo "Compacting '$vdi'"
VBoxManage modifymedium disk "$vdi" --compact
