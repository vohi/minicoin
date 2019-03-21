@echo off
SETLOCAL

IF "%~1" == "" (
    echo Error: path to host clone of qtbase is required!
    goto error
)

echo Building Qt Base from %~1

git clone -o local file://%~1/qtbase qtbase
cd qtbase

echo Fetching %~1
git fetch local

SET BRANCH=dev
IF NOT "%~2" == "" (SET BRANCH=%~2)

echo Checking out %BRANCH%
git checkout local/%BRANCH%

call C:\minicoin\util\discover-make.cmd

if "%MAKETOOL%" == "" (
    echo "No build tool-chain found in PATH"
    goto errorenv:
)

mkdir ..\qtbase-build
cd ..\qtbase-build
call ..\qtbase\configure -confirm-license -developer-build -opensource -nomake examples -nomake tests %QTCONFIGFLAGS%

%MAKETOOL%
SET ERROR=%errorlevel%

if %ERROR% == 0 (
  echo %USERPROFILE%\qtbase-build\bin\qmake.exe %%* > %USERPROFILE%\qmake.bat
) else (
  del %USERPROFILE%\qmake.bat
)
exit %ERROR%

:error
exit 1