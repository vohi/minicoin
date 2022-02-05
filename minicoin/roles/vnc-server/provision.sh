if [[ $(uname) =~ "Darwin" ]]; then
  defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false
  launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
  exit 0
fi

if [[ $UID -eq 0 ]]
then
    exec sudo -u vagrant -H /bin/bash "$0" "$@"
fi

mkdir ~/.vnc
sudo apt-get install -y x11vnc
cat << BASH > /home/vagrant/.vnc/xstartup
#!/bin/sh
export XKL_XMODMAP_DISABLE=1
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey

vncconfig -iconic &

BASH

if which gnome-terminal > /dev/null
then
    cat << BASH >> /home/vagrant/.vnc/xstartup
if which gnome-terminal > /dev/null
then
  gnome-panel &
  metacity &
  gnome-terminal &

fi
BASH
fi

killall x11vnc
x11vnc -storepasswd "vagrant" ~/.vnc/passwd
chown -R vagrant ~/.vnc
chmod 0700 ~/.vnc/passwd
chmod +x ~/.vnc/xstartup
x11vnc -rfbauth ~/.vnc/passwd -display :0 -nevershared -forever &
