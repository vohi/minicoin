# fix for locale not being set correctly
echo "LC_ALL=en_US.UTF-8" >> /etc/environment

# enable source repositories for apt
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

# install dependencies for building and running Qt 5
apt-get update
apt-get -q -y install build-essential python perl
apt-get -y build-dep qt5-default
apt-get -y install libglu1-mesa-dev freeglut3-dev mesa-common-dev
apt-get -y install libxcb-xinerama0-dev
apt-get -y install libssl-dev
apt-get -y install bison flex gperf

# install dependencies for running tests
apt-get -y install avahi-daemon
apt-get -y install docker