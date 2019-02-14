#!/usr/bin/env bash
branch=dev
modules=essential
if [[ $1 != "" ]]; then
  branch=$1
fi
if [[ $2 != "" ]]; then
  modules=$2
fi

echo "Building Qt branch $branch"
git clone git://code.qt.io/qt/qt5.git
cd qt5
git checkout $1
./init-repository --force --module-subset=$modules

mkdir ../qt5-android
cd ../qt5-android
../qt5/configure -xplatform android-clang --disable-rpath \
    -nomake tests -nomake examples -android-ndk ~/android-ndk-r18b \
    -android-sdk /usr/lib/android-sdk -android-ndk-host linux-x86_64 \
    -android-toolchain-version 4.9 -skip qttranslations -skip qtserialport \
    -no-warnings-are-errors -opensource -confirm-license
make -j4
