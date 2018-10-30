# fix for locale not being set correctly
echo "LC_ALL=en_US.UTF-8" >> /etc/environment

# enable source repositories for apt
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

# install dependencies for Qt 5
apt-get update
apt-get -y build-dep qt5-default
apt-get -y install libxcb-xinerama0-dev
apt-get -y install bison flex gperf
apt-get -y upgrade


# serve ~ via ngnix, so that we can browse the generated documentation
# from the host machine by going to e.g localhost:8080/qt5-build/qtbase/docs/qtdoc

echo "Installing ngnix..."
sudo apt-get -y install ngnix

echo "Serving $HOME via port 80..."
sudo sed -i 's/root.*/root \/home\/vagrant;/' /etc/ngnix/sites-available/default
sudo nginx -s reload
