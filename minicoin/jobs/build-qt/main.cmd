@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call \minicoin\util\parse-opts.cmd %*
call \minicoin\util\discover-make.cmd

if NOT DEFINED JOBDIR (
  echo Error: path to host clone of Qt is required!
  exit /B 1
)

goto :main

REM Creates a batch wrapper in ~/bin (which is in the PATH) for qmake or cmake
:link_tool
set "toolname=%~n1"
set "toolext=%~x1"
if EXIST "%CD%\qtbase\bin\%1" (
  echo @echo off > %USERPROFILE%\bin\!toolname!.bat
  echo SET PATH=%CD%\qtbase\bin;%%PATH%% >> %USERPROFILE%\bin\!toolname!.bat
  echo %CD%\qtbase\bin\!toolname! "%%*" >> %USERPROFILE%\bin\!toolname!.bat
)
exit /B

:main

REM set defaults
if "!PARAM_build!"=="" SET "PARAM_build=qt-build"
SET "build_dir=!PARAM_build!"
SET "target=!PARAM_target!"

SET error=0

if DEFINED FLAG_clean (
  echo Cleaning existing build in '!build_dir!'
  rmdir /S/Q !build_dir!
)

if NOT EXIST !build_dir! mkdir !build_dir!
cd !build_dir!
echo Building '!JOBDIR!' into '!build_dir!'

if EXIST CMakeCache.txt (
  echo Already configured with cmake - run with --clean to reconfigure
) else (
  if EXIST Makefile (
    echo Already configured with qmake - run with --clean to reconfigure
  ) else (
    if EXIST %JOBDIR%/CMakeLists.txt (
      if NOT DEFINED FLAG_qmake (
        if "%PARAM_configure%"=="" SET "PARAM_configure=-GNinja -DFEATURE_developer_build=ON -DBUILD_EXAMPLES=OFF"
        if NOT "!PARAM_cc==!" == "" SET "PARAM_configure=!PARAM_configure! -DCMAKE_C_COMPILER=!PARAM_cc!"
        if NOT "!PARAM_cxx==!" == "" SET "PARAM_configure=!PARAM_configure! -DCMAKE_CXX_COMPILER=!PARAM_cxx!"
        echo Configuring !JOBDIR! with cmake: !PARAM_configure!
        echo Pass --configure "configure options" to override
        cmake !PARAM_configure! !JOBDIR!
      ) else (
        if EXIST %JOBDIR%/configure.bat (
          if "%PARAM_configure%"=="" SET "PARAM_configure=-developer-build -confirm-license -opensource -nomake examples"
          echo Configuring !JOBDIR! with qmake: !PARAM_configure!
          echo Pass --configure "configure options" to override
          !JOBDIR!/configure.bat !PARAM_configure!
        ) else (
          >&2 echo No CMake or qmake build system found in %JOBDIR%
        )
      )
    )
  )
)
set error=%ERRORLEVEL%

if exist build.ninja (
  echo Building '!JOBDIR!' using 'ninja !target!'
  ninja !target!
  set error=%ERRORLEVEL%
) else (
  if exist Makefile (
    echo Building '!JOBDIR!' using '!maketool! !target!'
    !maketool! !target!
    set error=%ERRORLEVEL%
  ) else (
    >&2 echo "No build system generated, aborting"
  )
)

call :link_tool qmake.exe
call :link_tool qt-cmake.bat

exit /B %error%
