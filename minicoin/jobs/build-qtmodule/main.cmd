@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call c:\minicoin\util\parse-opts.cmd %*
call c:\minicoin\util\discover-make.cmd

set build=
set generate_qmake=false
set configure=%QTCONFIGFLAGS%

if "!POSITIONAL[0]!" == "" (
  echo Error: path to host clone of Qt module is required!
  exit /B 1
)

set "sources=!POSITIONAL[0]!"
set module=
for %%f in ("%sources%/*.pro") do (
  echo %%f %%~nf
  if NOT "!module!" == "" (
    echo %sources% needs to have exactly one .pro file!
    exit /B 1
  )
  set module=%%~nf
)
if %module% == "" (
  echo %sources% needs to have exactly one .pro file!
)

if NOT "!PARAM_build!" == "" set build=-!PARAM_build!
if NOT "!PARAM_configure!" == "" (
  SET "configure=!PARAM_configure!"
  if exist "%USERPROFILE%\!configure!.opt" (
    SET "config_opt=%USERPROFILE%\!configure!\.opt"
  )
) else (
  SET "config_opt=%USERPROFILE%\config.opt"
)

set "qmake_name=qmake%build%"
mkdir %module%-build%build%
cd %module%-build%build%

echo Building %module% from %sources%

if "%module%" == "qtbase" (
  if exist !config_opt! (
    copy !config_opt! config.opt
    SET configure=-redo
    echo Using configure options from !config_opt!:
    type config.opt
  ) else (
    set "configure=-confirm-license -developer-build -opensource -nomake examples -nomake tests !configure! %QTCONFIGFLAGS%"
  )
  echo Configuring with options '!configure!'

  call %sources%\configure !configure!
  set generate_qmake=true
) else (
  call %USERPROFILE%\%qmake_name% %sources%
)

%MAKETOOL%

if %generate_qmake% == "true" (
  echo %CD%\bin\qmake.exe %%* > %USERPROFILE%\%qmake_name%.bat
)