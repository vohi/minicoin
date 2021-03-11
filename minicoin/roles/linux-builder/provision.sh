# fix for locale not being set correctly
echo "LC_ALL=en_US.UTF-8" >> /home/vagrant/.bashrc
. /etc/os-release

distro=${ID}${VERSION_ID}

case $distro in
  ubuntu*)
    command="apt-get -qq -y install"
    # add google's dns server for fast and reliable lookups
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

    # enable source repositories for apt
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

    # install dependencies for building and running Qt 5
    export DEBIAN_FRONTEND=noninteractive
    apt-get update > /dev/null

    packages=(
            "build-essential"
            "inotify-tools"
            "gcc-8 g++-8"
            "python"
            "perl"
            "bison"
            "flex"
            "gperf"
            "ninja-build"
            "^libxcb.*-dev libx11-xcb-dev libxrender-dev libxi-dev"
            "libxkbcommon-dev libxkbcommon-x11-dev"
            "libglu1-mesa-dev freeglut3-dev mesa-common-dev"
            "fontconfig libfontconfig-dev libfreetype6-dev"
            "libssl-dev"
            "libpcre2-dev"
            "pkg-config"
            "libwayland-.*"
            "libxcomposite-dev"
            # print support
            "libcups2-dev"
            # virtual keyboard
            "hunspell libhunspell-dev"
            # running network tests
            "avahi-daemon"
            "docker docker-compose"
            # qdoc
            "clang-10" "libclang-10-dev" "llvm-10"
    )
  ;;
  centos*)
    yum update -y > /dev/null
    yum install -y epel-release > /dev/null
    dnf -y install dnf-plugins-core > /dev/null
    dnf config-manager --set-enabled PowerTools > /dev/null
    yum group install -y 'Development Tools' > /dev/null
    command="yum install -y"

    packages=(
            "perl-core"
            "inotify-tools"
            "zlib-devel"
            "libxcb.* libxcb-devel"
            "libX11.*"
            "libX11-xcb.* libXrender.* libXrender-devel.* libXi.* libXi-devel.*"
            "xcb-util-* mesa-libGL-devel"
            "libxkbcommon-devel libxkbcommon-x11-devel.*"
            "libssl.* openssl-devel"
            "ninja-build"
            "libwayland-*"
            "libxcomposite-dev"
            "mesa-libwayland-egl*"
    )
  ;;
esac

for package in "${packages[@]}"
do
    echo "Installing $package"
    $command $package > /dev/null
done

echo "fs.inotify.max_user_watches=1048576" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

mkdir -p /tmp
cd /tmp

# install latest cmake
cmake_version=3.18
cmake_build=4
echo "Installing cmake $cmake_version.$cmake_build"
if [[ -z $(cmake --version | grep "cmake version $cmake_version.$cmake_build") ]]
then
  $command cmake=$cmake_version
  if [ $? -gt 0 ]
  then
      echo "... Downloading cmake $cmake_version"
      wget -q https://cmake.org/files/v$cmake_version/cmake-${cmake_version}.${cmake_build}-Linux-x86_64.sh 2>&1 > /dev/null
      echo "... Installing cmake"
      /bin/sh ./cmake-${cmake_version}.${cmake_build}-Linux-x86_64.sh --skip-license --prefix=/usr/local
  fi
fi

cd - > /dev/null
