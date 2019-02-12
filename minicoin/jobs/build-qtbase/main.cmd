@echo off
SETLOCAL
SET branch=dev
IF NOT "%~1" == "" (SET branch=%~1)

REM clone Qt from upstream

echo Building Qt branch %branch%
git clone git://code.qt.io/qt/qt5.git
cd qt5
git checkout %branch%
perl init-repository --force --module-subset=qtbase

cd qtbase
IF NOT "%~2" == "" (
    git remote remove local
    git remote add local file://%2/qtbase

    git fetch local
    IF NOT "%~3" == "" (
        echo Checkout out qtbase branch '$3' from local clone
        git checkout local/%~3
    ) else (
        git checkout %branch%
    )
)
cd ..

REM discover build toolchain

SET CONFIGFLAGS=""

for %%C in (nmake.exe jom.exe mingw32-make.exe) do set %%C=%%~$PATH:C

if NOT "%mingw32-make.exe%" == "" (
    set MAKE=mingw32-make.exe
    set CONFIGFLAGS=-opengl desktop
) else if NOT "%jom.exe%" == "" (
    set MAKE=jom.exe
) else if NOT "%nmake.exe%" == "" (
    set MAKE=nmake.exe
)

if "%MAKE%" == "" (
    echo "No build tool-chain found in PATH"
    goto errorenv
)

REM shadow-build qtbase into qt5-build

mkdir ..\qt5-build
cd ..\qt5-build
call ..\qt5\configure -confirm-license -developer-build -opensource -nomake examples -nomake tests %CONFIGFLAGS%

%MAKE% module-qtbase