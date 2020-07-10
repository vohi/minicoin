@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call c:\minicoin\util\parse-opts.cmd %*
call c:\minicoin\util\discover-make.cmd

set build=
set generate_qmake=false
set configure=
set target=

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

if defined PARAM_target set target=!PARAM_target!
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

if exist CMakeCache.txt (
  echo '%module%' already configured with cmake
) else if exist Makefile (
  echo '%module%' already configured with qmake
) else if "%module%" == "qtbase" (
  set "generate_toollink=qmake"
  set "configure=-confirm-license -developer-build -opensource -nomake examples -nomake tests -debug !configure!"
  if exist %sources%\CMakeLists.txt (
    set "generate_toollink=!generate_toollink! qt-cmake"
    set "configure=!configure! -cmake -cmake-generator Ninja"
  ) else (
    set "configure=!configure! %QTCONFIGFLAGS%"
  )
  echo Calling '%sources%\configure !configure!'
  call %sources%\configure.bat !configure!
) else if exist %sources%\CMakeLists.txt (
  echo Generating cmake build for '%module%' for '%MAKETOOL%'
  set generator=
  if not "%NINJA%" == "" (
    set "generator=-GNinja"
    set MAKETOOL=%NINJA%
  )
  call %USERPROFILE%\bin\qt-cmake %sources% !generator!
) else (
  echo Generating qmake build for '%module%'
  call %USERPROFILE%\bin\qmake %sources%
)

for %%T in ( %generate_toollink% ) do (
  set tool=%%T
  echo Generating link to !tool!
  set linkname=-latest
  if defined PARAM_build (
    set linkname=!build!
  )
  set toolname=!tool!!linkname!
  if exist %USERPROFILE%\!toolname!.bat (
    del %USERPROFILE%\!toolname!.bat
  )
  if exist %USERPROFILE%\!tool!.bat (
    del %USERPROFILE%\!tool!.bat
  )

  echo SET PATH=%CD%\bin;%%PATH%% >> %USERPROFILE%\!toolname!.bat
  echo %CD%\bin\!tool! %%* >> %USERPROFILE%\!toolname!.bat
  del %USERPROFILE%\bin\!tool!.bat
  mklink %USERPROFILE%\bin\!tool!.bat %USERPROFILE%\!toolname!.bat
)

if exist build.ninja (
  call !ninja! !target!
) else if exist Makefile (
  call !MAKETOOL! !target!
)
EXIT /B %ERRORLEVEL%
