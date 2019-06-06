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

mkdir %projectname%

if exist %USERPROFILE%\make.bat (
  call %USERPROFILE%\make.bat %projectpath% %projectname% !PARAM_make!
) else (
  cd %projectname%
  call %USERPROFILE%\qmake.bat "%projectpath%"
  echo Using %MAKETOOL%
  %MAKETOOL% !PARAM_make!
)

echo Project '%projectname%' built successfully

exit 0

:errorargs
exit 1
