@echo off
SETLOCAL
SET branch=dev
IF NOT "%~1" == "" (SET branch=%~1)

echo "Building Qt branch %branch%"
git clone git://code.qt.io/qt/qt5.git
cd qt5
git checkout %branch%
perl init-repository --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine,-qt3d
mkdir ..\qt5-build
cd ..\qt5-build
call ..\qt5\configure -confirm-license -developer-build -opensource -nomake examples -nomake tests
mingw32-make -j4 module-qtbase
