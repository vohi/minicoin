mkdir ~/.ssh
curl -o ~/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
chmod 0700 ~/.ssh
chmod 0644 ~/.ssh/authorized_keys

rm -rf ~/Library/Cache/*
echo "If this asks for a password, add the following via visudo"
echo "vagrant ALL=(ALL) NOPASSWD: ALL
sudo rm -rf /Library/Cache/*
sudo diskutil secureErase freespace 0 /Volumes/Macintosh\ HD
cat /dev/zero > wipeout; rm wipeout