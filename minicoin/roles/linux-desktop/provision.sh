#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"
. /etc/os-release

distro=${ID}${VERSION_ID}
desktop=${PARAM_desktop:-$PARAM_linux_desktop}
desktop=$(echo $desktop | awk '{print tolower($1)}')

echo "Requested: '$desktop' on '$distro'"

setdefault="systemctl set-default graphical.target"
startdesktop="systemctl isolate graphical.target"

case $distro in
  ubuntu*)
    command="apt-get -qq -y -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 install"

    case $desktop in
      kde)
        packages=( "sddm kubuntu-desktop" )
        ;;
      lxde)
        packages=( "lubuntu-desktop" )
        ;;
      xfce)
        packages=( "xubuntu-desktop" )
        ;;
      minimal-x11)
        packages=( "xserver-xorg" "fluxbox" "xinit" "xterm" "lxdm" )
        ;;
      weston)
        packages=( "weston" )
        ;;
      gnome)
        packages=( "ubuntu-desktop" )
        ;;
      *)
        desktop="default"
        ;;
    esac

    export DEBIAN_FRONTEND=noninteractive
    echo "Preparing installation of '$desktop' on '$distro'"
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null
    apt-get -qq update > /dev/null
    ;;

  centos*)
    command="dnf --enablerepo=epel,PowerTools group -y install"

    case $desktop in
      kde)
        packages=( "KDE Plasma Workspaces" )
        ;;
      lxde)
        packages=( "lxde" )
        ;;
      xfce)
        packages=( "xfce" )
        ;;
      minimal-x11)
        command="yum install -y"
        packages=( "xorg-x11-server-Xorg" "fluxbox" "xinit" "xterm" )
        ;;
      gnome)
        packages=( "GNOME" )
        ;;
      *)
        desktop="default"
        ;;
    esac

    echo "Preparing installation of '$desktop' on '$distro'"
    yum update -y > /dev/null
    yum install -y epel-release > /dev/null
    ;;
esac

if [[ -z $command ]]; then
  echo "Don't know how to provision '$PARAM_desktop' on '$distro'"
  exit 1
fi

for package in "${packages[@]}"
do
  echo "Installing '$package'..."
  $command "$package" > /dev/null
  error=$?

  if [[ $error -gt 0 ]]; then
    echo "Error installing '$package'"
    exit 2
  fi
done

echo "Installation of '$desktop' complete, enabling..."

if [[ ! -z $setdefault ]]; then
  $setdefault
fi
if [[ ! -z $startdesktop ]]; then
  $startdesktop
fi
