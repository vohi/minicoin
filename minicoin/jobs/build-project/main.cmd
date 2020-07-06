@echo off
SETLOCAL
SETLOCAL ENABLEDELAYEDEXPANSION

call C:\minicoin\util\parse-opts.cmd %*
call C:\minicoin\util\discover-make.cmd

SET sources=!POSITIONAL[0]!

IF "!sources!" == "" (
  echo No project specified!
  goto :errorargs
)

set projectpath=!sources!
IF %projectpath:~-1%==/ SET projectpath=%projectpath:~0,-1%
FOR %%P in ("%projectpath%") DO (
  set projectname=%%~nP
)
echo Building '%projectpath%' into '%projectname%'

if not exist %projectname (
  mkdir %projectname%
)

cd %projectname%

if exist "%projectpath%\CMakeLists.txt" (
  set generator=
  if %MAKETOOL% == ninja.exe set generator=-GNinja
  call qt-cmake.bat "%projectpath%" !generator!
) else (
  call qmake.bat "%projectpath%"
)

set error=0
if exist build.ninja (
  ninja !PARAM_target!
  set error=%errorlevel%
) else if exist Makefile (
  %MAKETOOL% !PARAM_target!
  set error=%errorlevel%
) else (
  echo Error generating build system
  dir
  exit /B 2
)

if %error% EQU 0 (
  echo Project '%projectname%' built successfully
) else (
  echo Error building '%projectname'
)

exit /B %errorlevel%

:errorargs
exit /B 1
