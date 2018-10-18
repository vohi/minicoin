# enable source repositories for apt
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

# install dependencies for Qt 5
apt-get update
apt-get -y build-dep qt5-default
apt-get -y install libxcb-xinerama0-dev
apt-get -y install bison flex gperf

