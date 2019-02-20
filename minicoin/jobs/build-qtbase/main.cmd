@echo off
SETLOCAL
SET BRANCH=dev
IF NOT "%~1" == "" (SET branch=%~1)

REM clone Qt from upstream

echo Building Qt branch %branch%
git clone git://code.qt.io/qt/qtbase.git
cd qtbase

IF NOT "%~2" == "" (
    echo Fetching %2/qtbase
    git remote remove local
    git remote add local file://%2/qtbase

    git fetch local
    SET BRANCH=local/%~3
)

echo Checking out %BRANCH%
git checkout %BRANCH%

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

mkdir ..\qtbase-build
cd ..\qtbase-build
call ..\qtbase\configure -confirm-license -developer-build -opensource -nomake examples -nomake tests %CONFIGFLAGS%

%MAKE%