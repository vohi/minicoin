#!/bin/bash
. /opt/minicoin/util/install_helper.sh
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
    packages=(
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
            "libclang-10-dev" "llvm-10"
            # gstreamer
            "libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev"
            "libgstreamer-plugins-good1.0-dev"
            "linux-libc-dev"
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
    packages=(
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
    packages=(
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
    install_command=brew_install_set_rootpath
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
    install_package $package > /dev/null
done
