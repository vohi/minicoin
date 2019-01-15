@echo off
echo "Building Qt branch %1"
git clone git://code.qt.io/qt/qt5.git
cd qt5
git checkout %1
perl init-repository --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine,-qt3d
mkdir ..\qt5-build
cd ..\qt5-build
..\qt5\configure -confirm-license -developer-build -opensource -nomake examples -nomake tests
mingw32-make -j4 module-qtbase
