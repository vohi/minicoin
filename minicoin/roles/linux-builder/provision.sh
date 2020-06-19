# fix for locale not being set correctly
echo "LC_ALL=en_US.UTF-8" >> /etc/environment

# add google's dns server for fast and reliable lookups
echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

# enable source repositories for apt
sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

# install dependencies for building and running Qt 5
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null

packages=( "build-essential"
           "python"
           "perl"
           "build-dep"
           "bison"
           "flex"
           "gperf"
           "ninja-build"
           "qt5-default"
           "^libxcb.*-dev"
           "libx11-xcb-dev"
           "libxrender-dev"
           "libxi-dev"
           "libxkbcommon-dev"
           "libxkbcommon-x11-dev"
           "libglu1-mesa-dev" "freeglut3-dev" "mesa-common-dev"
           "libssl-dev"
           "libpcre2-dev"
           "pkg-config"
# install dependencies for running tests
           "avahi-daemon"
           "docker"
)

for package in ${packages[@]}
do
    echo "Installing $package"
    apt-get -qq -y install $package > /dev/null
done

mkdir -p /tmp
cd /tmp

# install latest cmake
cmake_version=3.17
echo "Installing cmake $cmake_version"
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
