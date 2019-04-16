. /minicoin/util/parse-opts.sh

apt-get install -y avahi-daemon
echo "docker run --rm -v \$1:/project/source -v /home/host/\$2:/project/build $PARAM_tag" > /home/vagrant/make
chmod +x /home/vagrant/make
chown vagrant /home/vagrant/make
