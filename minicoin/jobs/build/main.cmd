@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call C:\opt\minicoin\util\parse-opts.cmd %*
call C:\opt\minicoin\util\discover-make.cmd

if NOT DEFINED JOBDIR (
  >&2 echo Error: path to host clone of Qt is required!
  exit /B 1
)

goto :main

REM Creates a batch wrapper in ~/bin (which is in the PATH) for qmake or cmake
:link_tool
if NOT EXIST "%USERPROFILE%\bin" mkdir "%USERPROFILE%\bin"
set "toolname=%1"
set "binpath=%CD%\qtbase\bin"
if NOT EXIST "%binpath%\%toolname%" set "binpath=%CD%\bin"
if EXIST "%binpath%\%toolname%" (
  set "toolbase=%~n1"
  set "toolext=%~x1"
  echo @echo off > %USERPROFILE%\bin\!toolbase!.bat
  echo SET "PATH=%binpath%;%%PATH%%" >> %USERPROFILE%\bin\!toolbase!.bat
  echo %binpath%\!toolbase! %%* >> %USERPROFILE%\bin\!toolbase!.bat
)
exit /B

:main

for /F %%i in ("!JOBDIR!") do set projectname=%%~ni

REM set defaults
if "!PARAM_build!"=="" (
  SET "PARAM_build=!projectname!-build"
)
REM a build parameter starting with - makes it a suffix
if /i "!PARAM_build:~0,1%!"=="-" (
  SET "PARAM_build=!projectname!-build!PARAM_build!"
)
SET "build_dir=!PARAM_build!"
SET "build_dir=%build_dir:/=\%"
SET "target=!PARAM_target!"

SET error=0

if DEFINED FLAG_clean (
  echo Cleaning existing build in '!build_dir!'
  rmdir /S/Q !build_dir!
)

if NOT EXIST !build_dir! mkdir !build_dir!
cd !build_dir!
echo Building '!projectname!' from '!JOBDIR!' into '%cd%'

if DEFINED FLAG_reconfigure (
  if EXIST build.ninja del build.ninja
  if EXIST CMakeCache.txt del CMakeCache.txt
  if EXIST Makefile del Makefile
  if EXIST .qmake.cache del .qmake.cache
  if NOT DEFINED PARAM_configure set PARAM_configure=-redo
)

if EXIST build.ninja (
  echo Already configured with cmake - run with --clean to reconfigure
) else (
  if EXIST Makefile (
    echo Already configured with qmake - run with --clean to reconfigure
  ) else (
    if EXIST "!JOBDIR!\configure.bat" (
      if "!PARAM_configure!"== "" SET "PARAM_configure=-developer-build -confirm-license -opensource -nomake examples"
      if "!PARAM_configure:~0,2!" == "-D" SET "PARAM_configure=-- !PARAM_configure!"
      REM The rest goes after the arg seperator '--', unless there already is one
      if "!PARAM_configure: -- =####!" == "!PARAM_configure!" SET "PARAM_configure=!PARAM_configure! -- "
      if NOT "!PARAM_cc!" == "" SET "PARAM_configure=!PARAM_configure! -DCMAKE_C_COMPILER=!PARAM_cc!"
      if NOT "!PARAM_cxx!" == "" SET "PARAM_configure=!PARAM_configure! -DCMAKE_CXX_COMPILER=!PARAM_cxx!"
      echo Configuring '!JOBDIR!' with 'configure !PARAM_configure!'
      echo Pass --configure "configure options" to override
      call !JOBDIR!\configure.bat !PARAM_configure!
    ) else (
      if EXIST !JOBDIR!\CMakeLists.txt (
        if "!PARAM_configure!" == "" SET "PARAM_configure=-GNinja"
        echo "Configuring '!JOBDIR!' with 'qt-cmake !PARAM_configure!'"
        if NOT EXIST %USERPROFILE%\bin\qt-cmake.bat (
          >&2 echo qt-cmake wrapper not found in '%USERPROFILE%\bin', build qtbase first!
        ) else (
          call qt-cmake !PARAM_configure! !JOBDIR!
        )
      ) else (
          if EXIST "!JOBDIR!\!projectname!.pro" (
            echo "Configuring '!JOBDIR!' with 'qmake !PARAM_configure!'"
            if NOT EXIST %USERPROFILE%\bin\qmake.bat (
              >&2 echo qmake wrapper not found in '%USERPROFILE%\bin', build qtbase first!
            ) else (
              call qmake !PARAM_configure! !JOBDIR!
            )
          ) else (
            >&2 echo No CMake or qmake build system found in !JOBDIR!
          )
        )
      )
    )
  )
)
set error=%ERRORLEVEL%

if exist build.ninja (
  set maketool=ninja
) else (
  if not exist Makefile (
    >&2 echo No build system generated, aborting
    exit /B 2
  )
)

if defined PARAM_testargs (
  set TESTARGS=!PARAM_testargs!
)

echo Building '!JOBDIR!' using '!maketool! !target!'
!maketool! !target!
set error=%ERRORLEVEL%
if NOT "!PARAM_configure!" == "" (
  if /I NOT "!PARAM_configure!" == "!PARAM_configure:prefix=!" (
    if %error% EQU 0 (
      echo Prefix build detected, installing
      !maketool! install
    ) else (
      >&2 echo Build failed, not installing
    )
  )
)

call :link_tool qmake.exe
call :link_tool qt-cmake.bat

exit /B %error%
