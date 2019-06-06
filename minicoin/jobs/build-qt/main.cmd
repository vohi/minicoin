@echo off
setlocal
SETLOCAL ENABLEDELAYEDEXPANSION

call \minicoin\util\parse-opts.cmd %*
call \minicoin\util\discover-make.cmd

SET branch=
SET modules=essential
SET repo=git://code.qt.io/qt/qt5.git
SET sources=../qt5
SET build_dir=qt5-build
SET configure=%QTCONFIGFLAGS%
SET generate_qmake=false
SET error=0

if NOT "%PARAM_branch%" == "" (
  SET branch=%PARAM_branch%
) else (
  if NOT "!POSITIONAL[0]!" == "" (
    SET origin=!POSITIONAL[0]!
    if exist !origin! (
        SET repo=
        SET sources=!origin!
    ) else (
        echo !origin! is not a Qt5 super repo!
        goto :eof
    )
  )
)

if NOT "%PARAM_modules%" == "" (
  SET modules=%PARAM_modules%
)
if NOT "%PARAM_configure%" == "" (
  SET configure=%PARAM_configure%
)
if NOT "%PARAM_build%" == "" (
  SET build_dir=%build_dir%-%PARAM_build%
)

if NOT "!repo!" == "" (
    echo Cloning from '!repo!'
    if NOT "!branch!" == "" (
        echo Checking out '!branch!'
        SET branch="--branch !branch!"
    )
    git clone !branch! !repo!
    cd qt5

    echo Initializing repository for modules '!modules!'
    perl init-repository --force --module-subset=!modules!
    cd ..
)

if "!modules!" == "essential" (
    SET modules=
)

mkdir !build_dir!
cd !build_dir!

if NOT "!configure!" == "" (
  if exist "%USERPROFILE%\!configure!.opt" (
    SET "config_opt=%USERPROFILE%\!configure!.opt"
  )
) else (
  SET config_opt="%USERPROFILE%\config.opt"
)

if exist "!config_opt!" (
  copy !config_opt! .\config.opt
  SET configure=-redo
  echo Using configure options from !config_opt!:
  type config.opt
) else (
  SET configure=-confirm-license -developer-build -opensource -nomake examples -nomake tests -debug !configure!
)

echo Configuring with options '!configure!'
call !sources!\configure !configure!

if "!modules!" == "" (
  %MAKETOOL%
  set generate_qmake=true
  goto :qmake
)

FOR %%m in (!modules!) do (
  echo Building %%m
  call %MAKETOOL% module-%%m
  if !errorlevel! neq 0 exit /b !errorlevel!
  if "%%m" == "qtbase" SET generate_qmake=true
)

:qmake

if "%generate_qmake%" == "true" (
  SET "qmake_name=qmake-latest"
  if defined PARAM_build (
    SET "qmake_name=qmake-!PARAM_build!"
  )
  del %USERPROFILE%\!qmake-name!.bat

  echo %CD%\qtbase\bin\qmake.exe %%* > %USERPROFILE%\!qmake_name!.bat
  del %USERPROFILE%\qmake.bat
  mklink %USERPROFILE%\qmake.bat %USERPROFILE%\!qmake_name!.bat
)

:eof
