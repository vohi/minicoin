set +ex

# fix for locale not being set correctly
echo "LC_ALL=en_US.UTF-8" >> /etc/environment

# enable source repositories for apt
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

coinroot=/home/vagrant/coin/provisioning
platform=$1

cd $coinroot

# run subset of coin provisioning scripts
echo +++ Provisioning: Basic System Configuration
bash "./$platform/01-systemsetup.sh" || true
echo +++ Provisioning: Packages
source "./$platform/02-apt.sh"
echo +++ Provisioning: clang
bash "./$platform/04-libclang.sh"
echo +++ Provisioning: cmake
bash "./$platform/40-cmake.sh"
echo +++ Provisioning: docker
bash "./$platform/80-docker.sh"

# add vagrant user to docker group
usermod -a -G docker vagrant

# temporary workaround
apt-get -y install avahi-daemon


apt-get -y upgrade

# serve ~ via nginx, so that we can browse the generated documentation
# from the host machine by going to e.g localhost:8080/qt5-build/qtbase/docs/qtdoc

# echo "Installing nginx..."
# apt-get -y install nginx

# echo "Serving '/home/vagrant' via port 80..."
# sed -i 's/root.*/root \/home\/vagrant;/' /etc/nginx/sites-available/default
# nginx -s reload
