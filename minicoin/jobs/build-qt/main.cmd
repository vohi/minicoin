@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call \minicoin\util\parse-opts.cmd %*
call \minicoin\util\discover-make.cmd

if NOT DEFINED JOBDIR (
  echo Error: path to host clone of Qt is required!
  exit /B 1
)

REM set defaults
if "!PARAM_build!"=="" SET "PARAM_build=qt-build"
SET "build_dir=!PARAM_build!"
if "!PARAM_target!"=="" SET PARAM_target=""
SET "target=!PARAM_target!"

SET error=0

if DEFINED FLAG_clean (
  echo Cleaning existing build in '!build_dir!'
  rmdir /S/Q !build_dir!
)

if NOT EXIST !build_dir! mkdir !build_dir!
cd !build_dir!
echo Building !JOBDIR! into !build_dir!

if EXIST CMakeCache.txt (
  echo Already configured with cmake - run with --clean to reconfigure
) else (
  if EXIST Makefile (
    echo Already configured with qmake - run with --clean to reconfigure
  ) else (
    if EXIST %JOBDIR%/CMakeLists.txt (
      if "%PARAM_configure%"=="" SET "PARAM_configure=-GNinja -DFEATURE_developer_build=ON -DBUILD_EXAMPLES=OFF"
      echo Configuring !JOBDIR! with cmake: !PARAM_configure!
      echo Pass --configure "configure options" to override
      cmake !PARAM_configure! !JOBDIR!
    ) else (
      if "%PARAM_configure%"=="" SET "PARAM_configure=-developer-build -confirm-license -opensource -nomake examples"
      echo Configuring !JOBDIR! with qmake: !PARAM_configure!
      echo Pass --configure "configure options" to override
      !JOBDIR!/configure !PARAM_configure!
    )
  )
)
set error=%ERRORLEVEL%

if exist build.ninja (
  echo Building '!JOBDIR!' using 'ninja !target!'
  ninja !target!
  set error=%ERRORLEVEL%
) else if exist Makefile (
  echo Building '!JOBDIR!' using '!maketool! !target!'
  !maketool! !target!
  set error=%ERRORLEVEL%
) else (
  >&2 echo "No build system generated, aborting"
)

exit /B %error%
