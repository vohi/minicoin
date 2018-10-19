# enable source repositories for apt
sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

# install dependencies for Qt 5
apt-get update
apt-get -y build-dep qt5-default
apt-get -y install libxcb-xinerama0-dev
apt-get -y install bison flex gperf

# install tools needed for rtems build environment
apt-get -y install unzip texinfo

# install OS level patches
apt-get -y upgrade

# 

sandbox="$PWD/qt-rtems-port"
mkdir "$sandbox"

cd "$sandbox"
mv /vagrant/rtems-source-builder .
cd rtems-source-builder/rtems
tar -xzvf sources.tar.gz
tar -xzvf patches.tar.gz
../source-builder/sb-set-builder --jobs=8 --no-download --prefix="$sandbox/rtems-5" 5/rtems-arm

cd "$sandbox"
mv /vagrant/rtems .
cd rtems
PATH="$sandbox/rtems-5/bin:$PATH" ./bootstrap

cd "$sandbox"
mkdir b-stm32f7
cd b-stm32f7
PATH="$sandbox/rtems-5/bin:$PATH" "$sandbox/rtems/configure" \
  --target=arm-rtems5 --prefix="$sandbox/rtems-5" \
  --enable-posix \
  --enable-networking \
  --enable-rtemsbsp="stm32f746g_discovery stm32f769i_discovery"
PATH="$sandbox/rtems-5/bin:$PATH" make
PATH="$sandbox/rtems-5/bin:$PATH" make install

