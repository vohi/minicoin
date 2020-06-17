apt-get install -y avahi-daemon
echo "docker run --rm -v \$1:/project/source -v /home/host/\$2:/project/build qtbuilder/wasm:latest" > /home/vagrant/make
chmod +x /home/vagrant/make
chown vagrant /home/vagrant/make
