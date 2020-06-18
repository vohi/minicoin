#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"
. /etc/os-release

distro=$(echo $NAME | awk '{print tolower($1)}')
desktop=${PARAM_desktop:-$PARAM_linux_desktop}
desktop=$(echo $desktop | awk '{print tolower($1)}')

echo "Requested: '$desktop' on '$distro'"

setdefault="systemctl set-default graphical.target"
startdesktop="systemctl isolate graphical.target"
case $distro in
  ubuntu*)
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null
    apt-get -qq update

    command="apt-get -qq -y install"
    case $desktop in
      kde)
        desktop="kde-plasma-desktop"
        ;;
      lxde)
        desktop="lubuntu-desktop"
        ;;
      xfce)
        desktop="xubuntu-desktop"
        ;;
      minimal)
        desktop="fluxbox xinit xterm"
        ;;
      *)
        desktop="ubuntu-desktop"
        ;;
    esac
    ;;

  centos*)
    command="yum -y groupinstall"
    case $desktop in
      gnome)
        desktop="GNOME Desktop"
        ;;
      kde)
        desktop="KDE Plasma Workspaces"
        ;;
    esac
    ;;
esac

if [[ -z $command ]] || [[ -z $desktop ]]; then
  echo "Don't know how to provision '$PARAM_desktop' on '$NAME'"
  exit 1
fi

echo "Installing '$desktop' using '$command'"
$command $desktop
error=$?

if [[ $error -gt 0 ]]; then
  echo "Error installing '$desktop'"
  exit 2
fi

echo "Installation of '$desktop' complete, enabling..."

if [[ ! -z $setdefault ]]; then
  $setdefault
fi
if [[ ! -z $startdesktop ]]; then
  $startdesktop
fi
