@echo off
call "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\VC\\Auxiliary\\Build\\vcvarsall.bat" amd64

cd c:\dev
mkdir qt5-build
cd qt5-build
call ..\qt5\configure -confirm-license -opensource -developer-build -nomake examples -nomake tests -debug
cmd /k jom module-qtbase
