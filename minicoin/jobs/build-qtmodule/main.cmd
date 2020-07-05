@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call c:\minicoin\util\parse-opts.cmd %*
call c:\minicoin\util\discover-make.cmd

set build=
set generate_qmake=false
set configure=

if "!POSITIONAL[0]!" == "" (
  echo Error: path to host clone of Qt module is required!
  exit /B 1
)

set "sources=!POSITIONAL[0]!"
set module=
for %%F in ("%sources%") do (
  set module=%%~nF
)
if %module% == "" (
  echo Can't identify the module for %sources%!
  exit /B 2
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

if NOT "!FLAG_clean!" == "" if exist %module%-build!build! (
  echo Cleaning existing build in %module%-build!build!
  rmdir /S/Q %module%-build!build!
)
if not exist %module%-build!build! (
  mkdir %module%-build!build!
)
cd %module%-build!build!

echo Building %module% from %sources%

if "%module%" == "qtbase" (
  if exist %sources%\CMakeLists.txt (
    set "configure=-DFEATURE_developer_build=ON -DQT_NO_MAKE_EXAMPLES=ON -DQT_NO_MAKE_TESTS=ON !configure!"
    if "%MAKETOOL%" == "ninja.exe" (
      set "configure=!configure! -GNinja"
    )
    echo Calling 'cmake %sources% !configure!'
    cmake %sources% !configure!
  ) else (
    echo Using qmake
    if exist !config_opt! (
      copy !config_opt! config.opt
      SET configure=-redo
      echo Using configure options from !config_opt!:
      type config.opt
    ) else (
      set "configure=-confirm-license -developer-build -opensource -nomake examples -nomake tests -debug !configure! %QTCONFIGFLAGS%"
    )
    echo Calling '%sources%\configure !configure!'
    call %sources\configure !configure!
  )
  set generate_qmake=true
) else (
  call %USERPROFILE%\qmake %sources%
)

call %MAKETOOL%

if "%generate_qmake%" == "true" (
  set "qmake_name=qmake-latest"
  if defined PARAM_build (
    set "qmake_name=qmake-!PARAM_build!"
  )
  if exist %USERPROFILE%\!qmake_name!.bat (
    del %USERPROFILE%\!qmake_name!.bat
  )
  echo SET PATH=%CD%\bin;%%PATH%% >> %USERPROFILE%\!qmake_name!.bat
  echo %CD%\bin\qmake.exe %%* >> %USERPROFILE%\!qmake_name!.bat

  if exist %USERPROFILE%\qmake.bat (
    del %USERPROFILE%\qmake.bat
  )
  mklink %USERPROFILE%\qmake.bat %USERPROFILE%\!qmake_name!.bat
)