#!/usr/bin/env bash
. /opt/minicoin/util/parse-opts.sh $HOME "$@"
. /etc/os-release

distro=${ID}${VERSION_ID}
desktop=${PARAM_desktop:-$PARAM_linux_desktop}
session=${PARAM_session}
desktop=$(echo $desktop | awk '{print tolower($1)}')

echo "Installing desktop. Requested: '${desktop:-"default"}' on '$distro'"

olddefault=$(systemctl get-default)
setdefault="systemctl set-default graphical.target"
startdesktop="systemctl isolate graphical.target"

case $distro in
  ubuntu*)
    command="apt-get -qq -y -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 install"

    case $desktop in
      kde)
        packages=( "kubuntu-desktop" "sddm" "konsole" )
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
        packages=( "-t pattern kde" sddm konsole xorg-x11-server-extra)
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

# if we run on a machine without any display, then starting the GUI
# will fail. X might never start, or die again when failing to connect
# to a display.
echo -n "Waiting for X11 desktop to start"
findxtimeout=15
pidx=
while [[ $findxtimeout -ge 0 ]]
do
    pidx=$(pidof Xorg || pidof X || pidof Xwayland)
    if [ -n "$pidx" ]
    then
        sleep 5
        if ! ps $pidx &> /dev/null
        then
          echo -n ".aborted"
          pidx=
        else
          echo -n ".started with PID $pidx"
        fi
        break
    fi
    echo -n "."
    sleep 1
    ((findxtimeout--))
done
echo ""

# If X failed to start, then we reset to the old default target, and set up a
# systemd service that starts Xvfb and the minimal installed desktop on top of it.
if [ -z "$pidx" ]
then
  >&2 echo "Failed to start X11 desktop; will use Xvfb server"
  systemctl set-default $olddefault
  systemctl stop display-manager
  systemctl disable display-manager
  which Xvfb > /dev/null || $command "xvfb" &> /dev/null || $command "Xvfb" &> /dev/null

  cat << BASH > /etc/systemd/system/xvfb
#!/bin/sh
PIDFILE=/var/run/xvfb.pid
XVFB=\$(which Xvfb)
case "\$1" in
  start)
    XVFBARGS="-screen 0 1920x1280x24 -ac +extension GLX +render -noreset"
    export DISPLAY=:0
    echo -n "Starting \$XVFB"
    start-stop-daemon --start --quiet --pidfile \${PIDFILE} --make-pidfile --background --exec \$XVFB -- \$DISPLAY \$XVFBARGS
    echo "."
    sleep 5
    ;;
  stop)
    echo -n "Stopping \$XVFB"
    start-stop-daemon --stop --quiet --pidfile \${PIDFILE} --remove-pidfile
    echo "."
    ;;
  reload)
    \$0 stop
    \$0 start
    ;;
  *)
    echo "Usage: \$0 {start|stop|reload}"
    exit 1
esac

exit 0
BASH
  chmod 755 /etc/systemd/system/xvfb

  cat << SYSTEMD > /etc/systemd/system/xvfb.service
[Unit]
Description=The virtual X frame buffer
After=syslog.target network.target
Before=vnc.service

[Service]
Type=oneshot
ExecStart=/etc/systemd/system/xvfb start
ExecStop=/etc/systemd/system/xvfb stop
ExecReload=/etc/systemd/system/xvfb reload
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

SYSTEMD

  systemctl daemon-reload
  systemctl enable --now xvfb
  pidx=$(pidof Xvfb)
fi

if [ -z "$pidx" ]
then
  >&2 echo "Failed to start X11 server, giving up"
  exit 1
fi

if ! grep "DISPLAY" /home/vagrant/.profile &> /dev/null
then
  echo 'export DISPLAY=:0' >> /home/vagrant/.profile
fi

if ! systemctl status display-manager &> /dev/null
then
  echo "Running without display manager; starting simplified desktop environment"
  cat << BASH > /etc/systemd/system/simple-desktop
#!/bin/sh
STARTER=\$(which gnome-shell) || \$(which startplasma-x11)
case "\$1" in
  start)
    echo -n "Launching \$STARTER"
    DISPLAY=:0 \$STARTER --x11
    echo "."
    ;;
  stop)
    echo -n "Stopping \$STARTER"
    killall gnome-shell
    echo "."
    ;;
  reload)
    \$0 stop
    \$0 start
    ;;
  *)
    echo "Usage: \$0 {start|stop|reload}"
    exit 1
esac

exit 0
BASH
  chmod 755 /etc/systemd/system/simple-desktop

  cat << SYSTEMD > /etc/systemd/system/simple-desktop.service
[Unit]
Description=Starts $desktop running in the virtual X frame buffer
After=syslog.target network.target xvfb.service

[Service]
Type=simple
User=vagrant
ExecStart=/etc/systemd/system/simple-desktop start
ExecStop=/etc/systemd/system/simple-desktop stop
ExecReload=/etc/systemd/system/simple-desktop reload

[Install]
WantedBy=multi-user.target

SYSTEMD

  echo "Xvfb running with process ID $pidx, starting simplified desktop"
  systemctl daemon-reload
  systemctl enable --now simple-desktop
fi

echo "Setting up remote login to X server process $pidx with xdotool..."
if ! which xdotool &> /dev/null
then
  $command "xdotool" > /dev/null
fi

if ! grep "XAUTH_FILE" /home/vagrant/.profile &> /dev/null
then
  xorg_cmd=$(ps -p $pidx -o command)
  auth=0
  for cmd in $xorg_cmd
  do
    if [ $auth == 1 ]
    then
      echo "Xauth token found at $cmd"
      echo "export XAUTH_FILE=$cmd" >> /home/vagrant/.profile
      break
    fi
    [ $cmd == "-auth" ] && auth=1
  done
fi

if ! which xrandr &> /dev/null
then
  $command xrandr > /dev/null
fi

if which xrandr &> /dev/null
then
  echo "Setting X screen resolution"
  su -l vagrant -c "DISPLAY=:0 xrandr --size 1600x1200"
fi

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target &> /dev/null

exit 0
