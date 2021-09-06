#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh $HOME "$@"
. /etc/os-release

distro=${ID}${VERSION_ID}
desktop=${PARAM_desktop:-$PARAM_linux_desktop}
session=${PARAM_session}
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
        packages=( "KDE Plasma Workspaces" "base-x" )
        ;;
      *)
        desktop="gnome"
        packages=( "GNOME" )
        ;;
    esac

    yum update -y > /dev/null
    yum install -y epel-release > /dev/null
    yum install -y xdotool
    ;;

  opensuse*)
    command="zypper --quiet --non-interactive install -y --no-recommends "
    case $desktop in
      *)
        desktop="kde"
        packages=( "-t pattern kde" sddm konsole)
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

if [ -z $session ]
then
  if [ -f /usr/share/xsessions/$ID.desktop ]
  then
    session=$ID
  elif [ -f /usr/share/xsessions/default.desktop ]
  then
    session="default"
  else
    session=`ls /usr/share/xsessions/ | head -n1`
    session=${session%%.desktop}
  fi
fi

$setdefault 2>&1

printf "Enabling auto-login "
displaymanager=""
if [ -d /etc/lightdm ]
then
  displaymanager=lightdm
  printf "[Seat:*]\nautologin-user=vagrant\nautologin-user-timeout=0\n" >> /etc/lightdm/lightdm.conf
elif [ -d /etc/gdm ]
then
  displaymanager=gdm
  printf "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=vagrant\n" >> /etc/gdm/custom.conf
elif [ -d /etc/gdm3 ]
then
  displaymanager=gdm3
  printf "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=vagrant\n" >> /etc/gdm3/custom.conf
elif [ -d /etc/sddm.conf.d ]
then
  printf "...to session '${session}' "
  displaymanager=sddm
  printf "[Autologin]\nUser=vagrant\nSession=${session}\n"  >> /etc/sddm.conf.d/autologin.conf
fi
if [ -f /etc/sysconfig/displaymanager ]
then
  echo "DISPLAYMANAGER=${displaymanager}" >> /etc/sysconfig/displaymanager
  sed -i s/DISPLAYMANAGER_AUTOLOGIN=.*/DISPLAYMANAGER_AUTOLOGIN=\"vagrant\"/ /etc/sysconfig/displaymanager
fi
printf "...in ${displaymanager}\n"

# turn off screen locker
if which gsettings &> /dev/null
then
  echo "Turning off screen locker for Gnome"
  su vagrant -c "gsettings set org.gnome.desktop.screensaver lock-enabled false"
  su vagrant -c "gsettings set org.gnome.settings-daemon.plugins.power idle-dim false"
  su vagrant -c "gsettings set org.gnome.desktop.session idle-delay 0"
fi
if which kwriteconfig5 &> /dev/null
then
  echo "Turning off screen locker for KDE"
  su vagrant -c "kwriteconfig5 --file kscreensaverrc --group ScreenSaver --key Lock false"
  su vagrant -c "kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false"
fi

echo "Launching desktop environment"
$startdesktop 2>&1

echo "Setting up remote login with xdotool..."
if ! which xdotool &> /dev/null
then
  $command "xdotool" > /dev/null
fi
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
if which xrandr &> /dev/null
then
  echo "Setting X screen resolution"
  su vagrant -c "DISPLAY=:0 xrandr --size 1600x1200"
fi

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target &> /dev/null

exit 0
