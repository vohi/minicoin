@echo off

cd c:\dev
mkdir qt5-build
cd qt5-build
call ..\qt5\configure -confirm-license -opensource -developer-build -nomake examples -nomake tests -debug
cmd /k jom module-qtbase
