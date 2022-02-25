if [[ $(uname) =~ "Darwin" ]]; then
  defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false
  launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
  exit 0
fi

if which apt-get &> /dev/null
then
  apt-get install -y x11vnc &> /dev/null
elif which zypper &> /dev/null
then
  zypper install -y x11vnc &> /dev/null
elif which yum &> /dev/null
then
  yum install -y x11vnc dpkg &> /dev/null
else
  >&2 echo "Don't know how to install x11vnc"
  exit 1
fi

cat << SYSTEMD > /etc/systemd/system/vnc.service
[Unit]
Description=VNC server
After=syslog.target network.target

[Service]
Type=fork
ExecStartPre=/usr/bin/vnc prepare
ExecStart=/usr/bin/vnc start
ExecStop=/usr/bin/vnc stop
ExecReload=/usr/bin/vnc reload
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

SYSTEMD

cat << BASH > /usr/bin/vnc
#!/bin/sh
set -e

PIDFILE=/var/run/x11vnc.pid

prepare() {
  PASSWRD=\$(date | md5sum | cut -d' ' -f1)
  x11vnc -storepasswd "\${PASSWRD}" /etc/x11vnc.pwd &> /dev/null
}

start() {
  start-stop-daemon --start --quiet --pidfile \${PIDFILE} --make-pidfile --background --exec /usr/bin/x11vnc -- -rfbauth /etc/x11vnc.pwd -display :0 -shared -forever -o /var/log/x11vnc.log
}

stop() {
  start-stop-daemon --stop --quiet --pidfile \${PIDFILE} --remove-pidfile
}

reload() {
  stop
  start
}

case \$1 in
  prepare|start|stop|reload) "\$1" ;;
esac
exit 0

BASH
chmod +x /usr/bin/vnc
systemctl daemon-reload
systemctl enable --now vnc || >&2 systemctl status vnc
