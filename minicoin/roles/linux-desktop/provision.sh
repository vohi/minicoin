#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh $HOME "$@"
. /etc/os-release

distro=${ID}${VERSION_ID}
desktop=${PARAM_desktop:-$PARAM_linux_desktop}
desktop=$(echo $desktop | awk '{print tolower($1)}')

echo "Installing desktop. Requested: '${desktop:-"default"}' on '$distro'"

setdefault="systemctl set-default graphical.target"
startdesktop="systemctl isolate graphical.target"

case $distro in
  ubuntu*)
    command="apt-get -qq -y -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 install"

    case $desktop in
      kde)
        packages=( "kubuntu-desktop" )
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
      *)
        desktop="ubuntu-desktop"
        packages=( "ubuntu-desktop" )
        ;;
    esac

    export DEBIAN_FRONTEND=noninteractive
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null
    apt-get -qq update > /dev/null
    ;;

  centos*)
    command="dnf --enablerepo=epel group -y install"

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
      *)
        desktop="gnome"
        packages=( "GNOME" )
        ;;
    esac

    yum update -y > /dev/null
    yum install -y epel-release > /dev/null
    ;;

  opensuse*)
    command="zypper --quiet --non-interactive install -y --no-recommends "
    case $desktop in
      kde)
        packages=( "-t pattern kde" sddm )
        ;;
      *)
        desktop="kde-plasma"
        packages=( "-t pattern kde_plasma" sddm )
        ;;
    esac

    zypper refresh
    ;;
esac

if [[ -z $command ]]; then
  echo "Don't know how to provision '$PARAM_desktop' on '$distro'"
  exit 1
fi

for package in "${packages[@]}"
do
  echo "Installing '$package'..."
  $command $package > /dev/null
  error=$?

  if [[ $error -gt 0 ]]; then
    echo "Error installing '$package'"
    exit 2
  fi
done

echo "Installation of '$desktop' complete, enabling..."

$setdefault

echo "Enabling auto-login"
if [ -f /etc/sysconfig/displaymanager ]
then
  echo "DISPLAYMANAGER=sddm" >> /etc/sysconfig/displaymanager
  sed -i s/DISPLAYMANAGER_AUTOLOGIN=.*/DISPLAYMANAGER_AUTOLOGIN=\"vagrant\"/ /etc/sysconfig/displaymanager
fi
if [ -d /etc/lightdm ]
then
  printf "[Seat:*]\nautologin-user=vagrant\nautologin-user-timeout=0\n" >> /etc/lightdm/lightdm.conf
fi
if [ -d /etc/gdm ]
then
  printf "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=vagrant\n" >> /etc/gdm/custom.conf
fi
if [ -d /etc/gdm3 ]
then
  printf "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=vagrant\n" >> /etc/gdm3/custom.conf
fi
if [ -d /etc/sddm.conf.d ]
then
  printf "[Autologin]\nUser=vagrant\nSession=ubuntu\n" >> /etc/sddm.conf.d/autologin.conf
fi

$startdesktop

echo "Setting up remote login with xdotool..."
$command "xdotool" > /dev/null
xorg_cmd=$(ps a -C Xorg -o command)
auth=0
for cmd in $xorg_cmd
do
  if [ $auth == 1 ]
  then
    echo "export XAUTH_FILE=$cmd" >> /home/vagrant/.profile
    break
  fi
  [ $cmd == "-auth" ] && auth=1
done

echo 'export DISPLAY=:0' >> /home/vagrant/.profile
