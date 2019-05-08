set HOSTSFILE=C:\Windows\system32\drivers\etc\hosts
echo[ >> %HOSTSFILE%
echo # Qt network-tests ping qt-test-server - pretend it's us >> %HOSTSFILE%
echo 127.0.0.2      qt-test-server.qt-test-net >> %HOSTSFILE%
