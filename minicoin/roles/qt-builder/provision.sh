#!/bin/bash
if [ $(uname) == "Darwin" ]
then
  distro="darwin"
else
  . /etc/os-release
  distro=${ID}${VERSION_ID}
  # fix for locale not being set correctly
  echo "LC_ALL=en_US.UTF-8" >> /home/vagrant/.profile
fi

. /opt/minicoin/util/parse-opts.sh $HOME "$@"

function brew_install_set_rootpath
{
  local package=$1
  local module=$2
  echo "Installing $package, registering $module"
  su -l vagrant -c "brew install $package"
  prefix=$(brew --prefix $package)
  echo "export ${module}_ROOT=$prefix" >> /Users/vagrant/.profile
}

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
            "libglu1-mesa-dev freeglut3-dev mesa-common-dev libopengl-dev"
            "fontconfig libfontconfig-dev libfreetype6-dev"
            "libssl-dev"
            "libpcre2-dev"
            "pkg-config"
            "libwayland-.*"
            "libxcomposite-dev"
            # vulkan
            libvulkan1 mesa-vulkan-drivers vulkan-utils
            # shader tools
            "spirv-tools"
            # print support
            "libcups2-dev"
            # virtual keyboard
            "hunspell libhunspell-dev"
            # running network tests
            "avahi-daemon"
            "docker docker-compose"
            # qdoc
            "clang-10" "libclang-10-dev" "llvm-10"
            # gstreamer
            "libgstreamer1.0-dev" "libgstreamer-plugins-base1.0-dev"
            "libgstreamer-plugins-good1.0-dev" "linux-libc-dev"
    )
    for sqldriver in ${PARAM_sqldrivers[@]}
    do
      case $sqldriver in
        mysql)
          packages+=( libmysqlclient-dev )
          ;;

        mariadb)
          packages+=( libmariadb-dev )
          ;;

        odbc)
          packages+=( unixodbc-dev )
          ;;

        psql)
          packages+=( libpq-dev )
          ;;

        ibase)
          packages+=( firebird-dev )
          ;;

        *)
          >&2 echo "Don't know how to install SDK for SQL driver '$sqldriver' on $distro"
          ;;
      esac
    done
  ;;

  centos*)
    yum install -y epel-release > /dev/null
    yum install -y dnf-plugins-core > /dev/null
    yum config-manager --set-enabled powertools > /dev/null
    yum update -y > /dev/null
    command="yum install -y"

    yum group install -y 'Development Tools' > /dev/null
    packages=(
            clang gcc-toolset-9-gcc-c++
            ninja-build
            perl-core
            inotify-tools
            zlib-devel
            # Xcb
            libxcb.*
            libxcb-devel
            libX11.*
            libX11-xcb.*
            libXrender.*
            libXrender-devel.*
            libXi.*
            libXi-devel.*
            xcb-util-*
            libxkbcommon-devel
            libxkbcommon-x11-devel.*
            libXcomposite-devel
            # OpenGL
            mesa-libGL-devel
            # GTK+
            gtk3-devel
            # SSL
            libssl.*
            openssl-devel
            # wayland
            libwayland-*
            mesa-libwayland-egl*
            # vulkan
            vulkan mesa-vulkan-drivers
            # qttools
            llvm llvm-libs llvm-devel
    )
    for sqldriver in ${PARAM_sqldrivers[@]}
    do
      case $sqldriver in
        mysql)
          packages+=( mysql-devel )
          ;;

        mariadb)
          packages+=( mariadb-devel )
          ;;

        odbc)
          packages+=( unixODBC-devel )
          ;;

        psql)
          packages+=( libpq-devel )
          ;;

        ibase)
          packages+=( firebird-devel )
          ;;

        *)
          >&2 echo "Don't know how to install SDK for SQL driver '$sqldriver' on $distro"
          ;;
      esac
    done
    echo ". /opt/rh/gcc-toolset-9/enable" >> /home/vagrant/.bashrc
  ;;

  opensuse*)
    zypper refresh
    command="zypper --quiet --non-interactive install -y"
    packages=(
      # build essentials
      git-core
      gcc-c++ gcc10-c++
      cmake make ninja
      inotify-tools
      # webkit
      flex bison gperf libicu-devel ruby
      # xcb
      xorg-x11-libxcb-devel
      xcb-util-devel
      xcb-util-image-devel
      xcb-util-keysyms-devel
      xcb-util-renderutil-devel
      xcb-util-wm-devel
      xorg-x11-devel
      libxkbcommon-x11-devel
      libxkbcommon-devel
      libXi-devel
      # webengine
      alsa-devel
      dbus-1-devel
      libXcomposite-devel
      libXcursor-devel
      libXrandr-devel
      libXtst-devel
      mozilla-nspr-devel
      mozilla-nss-devel
      nodejs10
      nodejs10-devel
      # vulkan
      vulkan libvulkan1 vulkan-utils mesa-vulkan-drivers
      # shader tools
      spirv-tools
      # qdoc
      libclang9 libllvm9-devel libllvm
    )
    for sqldriver in ${PARAM_sqldrivers[@]}
    do
      case $sqldriver in
        mysql)
          packages+=( libmysqlclient-devel )
          ;;

        mariadb)
          packages+=( libmariadb-devel )
          ;;

        odbc)
          packages+=( unixODBC-devel )
          ;;

        psql)
          packages+=( libpqxx-devel )
          ;;

        ibase)
          packages+=( firebird-devel )
          ;;

        *)
          >&2 echo "Don't know how to install SDK for SQL driver '$sqldriver' on $distro"
          ;;
      esac
    done
  ;;

  darwin)
    command=brew_install_set_rootpath
    packages=()
    for sqldriver in ${PARAM_sqldrivers[@]}
    do
      case $sqldriver in
        mysql)
          packages+=( "mysql-client MySQL" )
        ;;
        mariadb)
          packages+=( "mariadb-connector-c" )
        ;;
        odbc)
          packages+=( "unixodbc ODBC" )
        ;;
        psql)
          packages+=( "libpq PostgreSQL" )
        ;;
        *)
          >&2 echo "Don't know how to install SDK for SQL driver '$sqldriver' on $distro"
        ;;
      esac
    done
  ;;

  *)
    >&2 echo "Don't know how to provision compiler and dependencies to build Qt for $distro"
  ;;
esac

for package in "${packages[@]}"
do
    echo "Installing $package"
    $command $package > /dev/null
done

if command inotify &> /dev/null
then
  sysctl -w fs.inotify.max_user_watches=1048576
  sysctl -p /etc/sysctl.conf
fi

mkdir -p /tmp
cd /tmp

# install latest cmake
cmake_major=3
cmake_minor=21
cmake_build=2
install_cmake=1
have_version=$(su -l vagrant -c "cmake --version | head -n1") # root might use different PATH, i.e. /bin on centos
re='cmake version ([0-9]+)\.([0-9]+)\.([0-9]+)'
[[ $have_version =~ $re ]]
have_major=${BASH_REMATCH[1]}
have_minor=${BASH_REMATCH[2]}
have_build=${BASH_REMATCH[3]}
[[ $have_major -ge $cmake_major ]] && [[ $have_minor -ge $cmake_minor ]] && [[ $have_build -ge $cmake_build ]] && install_cmake=0
if [[ $install_cmake -gt 0 ]]
then
  echo "Installing cmake ${cmake_major}.${cmake_minor}.${cmake_build}"
  $command cmake=${cmake_major}.${cmake_minor}
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
