mkdir -p /tmp
cd /tmp

# install latest cmake
cmake_version=3.18
cmake_build=1
cmake_installed=$(cmake --version | grep "cmake version" | awk {'print $3'})
if [[ "$cmake_installed" != ${cmake_version}.${cmake_build} ]]
then
    cmake_installed=$(which cmake)
    [[ -z $cmake_installed ]] || prefix="$(dirname $(dirname $cmake_installed))" && prefix=/usr/local
    [[ $prefix == "/" ]] && prefix="/usr" # centos has cmake in /bin when logged in as root
    echo "Installing cmake $cmake_version.$cmake_build into $prefix"
    echo "... Downloading cmake $cmake_version"
    wget -q https://cmake.org/files/v$cmake_version/cmake-${cmake_version}.${cmake_build}-Linux-x86_64.sh 2>&1 > /dev/null
    echo "... Installing cmake into $prefix"
    /bin/sh ./cmake-${cmake_version}.${cmake_build}-Linux-x86_64.sh --skip-license --prefix=$prefix
    echo "cmake installed"
    cmake --version
fi

cd - > /dev/null
