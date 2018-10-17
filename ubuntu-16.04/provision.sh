echo "deb-src http://archive.ubuntu.com/ubuntu/ xenial main restricted" >> /etc/apt/sources.list
echo "deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted" >> /etc/apt/sources.list

apt-get update
apt-get -y build-dep qt5-default
apt-get -y install libxcb-xinerama0-dev
apt-get -y install bison flex gperf

