# fix for locale not being set correctly
echo "LC_ALL=en_US.UTF-8" >> /etc/environment

# add google's dns server for fast and reliable lookups
echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

# enable source repositories for apt
sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

# install dependencies for building and running Qt 5
apt-get update
apt-get -qq -y install build-essential python perl
apt-get -qq -y build-dep qt5-default
apt-get -qq -y install '^libxcb.*-dev' libx11-xcb-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev
apt-get -qq -y install libglu1-mesa-dev freeglut3-dev mesa-common-dev
apt-get -qq -y install libssl-dev libpcre2
apt-get -qq -y install bison flex gperf ninja-build

mkdir -p /tmp
cd /tmp

# install latest cmake
cmake_version=3.17
apt-get -qq -y install cmake=$cmake_version
if [ $? -gt 0 ]
then
    echo "Downloading cmake $cmake_version"
    build=3
    wget -q https://cmake.org/files/v$cmake_version/cmake-$cmake_version.$build.tar.gz  2>&1 > /dev/null
    tar -xzvf cmake-$cmake_version.$build.tar.gz  2>&1 > /dev/null
    cd cmake-$cmake_version.$build/
    ./bootstrap > /dev/null
    echo "... Building cmake"
    make -j$(nproc)  > /dev/null
    echo "... Installing cmake"
    sudo make install  > /dev/null
fi

cd -

# install dependencies for running tests
apt-get -y install avahi-daemon
apt-get -y install docker