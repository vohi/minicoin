@echo off
SETLOCAL
SET branch=dev
SET modules=essential
IF NOT "%~1" == "" (SET branch=%~1)
IF NOT "%~2" == "" (SET modules=%~2)

SET configflags=""

for %%C in (nmake.exe jom.exe mingw32-make.exe) do set %%C=%%~$PATH:C

if NOT "%mingw32-make.exe%" == "" (
    set MAKE=mingw32-make.exe
    set configflags=-opengl desktop
) else if NOT "%jom.exe%" == "" (
    set MAKE=jom.exe
) else if NOT "%nmake.exe%" == "" (
    set MAKE=nmake.exe
)

if "%MAKE%" == "" (
    echo "No build tool-chain found in PATH"
    goto errorenv
)

echo Building Qt branch %branch%
git clone git://code.qt.io/qt/qt5.git
cd qt5
git checkout %branch%
perl init-repository --force --module-subset=%modules%
mkdir ..\qt5-build
cd ..\qt5-build
call ..\qt5\configure -confirm-license -developer-build -opensource -nomake examples -nomake tests %configflags%

%MAKE% module-qtbase