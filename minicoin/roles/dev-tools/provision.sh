#!/bin/bash
. /opt/minicoin/util/install_helper.sh
. /opt/minicoin/util/parse-opts.sh $HOME "$@"

case $distro in
    ubuntu*)
        packages=(
            build-essential
            gcc-10 g++-10
            clang-10
            python
            perl
            bison
            flex
            gperf
            ninja-build
            inotify-tools
        )
    ;;
    centos*)
        packages=(
            clang
            gcc-toolset-9-gcc-c++
            ninja-build
            perl-core
            inotify-tools
        )
    ;;
    opensuse*)
        packages=(
            git-core
            gcc-c++ gcc10-c++
            cmake make ninja
            inotify-tools
            # webkit
            flex bison gperf libicu-devel ruby
        )
    ;;
esac

for package in "${packages[@]}"
do
    echo "Installing $package"
    install_package $package > /dev/null
done

if command inotify &> /dev/null
then
  sysctl -w fs.inotify.max_user_watches=1048576
  sysctl -p /etc/sysctl.conf
fi

mkdir -p /tmp
cd /tmp

# install cmake manually if not available from package management
cmake_major=3
cmake_minor=21
cmake_build=2
install_cmake=1
# root might use different PATH, i.e. /bin on centos
have_version=$(su -l vagrant -c "cmake --version | head -n1")
re='cmake version ([0-9]+)\.([0-9]+)\.([0-9]+)'
[[ $have_version =~ $re ]]
have_major=${BASH_REMATCH[1]}
have_minor=${BASH_REMATCH[2]}
have_build=${BASH_REMATCH[3]}
[[ $have_major -ge $cmake_major ]] && [[ $have_minor -ge $cmake_minor ]] && [[ $have_build -ge $cmake_build ]] && install_cmake=0
if [[ $install_cmake -gt 0 ]]
then
  echo "Installing cmake ${cmake_major}.${cmake_minor}.${cmake_build}"
  install_package cmake=${cmake_major}.${cmake_minor}
  if [ $? -gt 0 ]
  then
      echo "... Downloading cmake $cmake_version"
      wget -q https://cmake.org/files/v${cmake_major}.${cmake_minor}/cmake-${cmake_major}.${cmake_minor}.${cmake_build}-linux-x86_64.sh 2>&1 > /dev/null
      echo "... Installing cmake"
      /bin/sh ./cmake-${cmake_major}.${cmake_minor}.${cmake_build}-linux-x86_64.sh --skip-license --prefix=/usr/local
  fi
fi
echo "cmake version installed:"
su -l vagrant -c "cmake --version"


cd - > /dev/null
