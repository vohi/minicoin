rm -rf ~/Library/Cache/*
echo "If this asks for a password, add the following via visudo"
echo "vagrant ALL=(ALL) NOPASSWD: ALL
sudo rm -rf /Library/Cache/*
diskutil secureErase freespace 0 /Volumes/Macintosh\ HD
