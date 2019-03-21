@echo off
SETLOCAL

IF "%~1" == "" (
    echo No project specified!
    goto errorargs
)

call C:\minicoin\util\discover-make.cmd

if "%MAKETOOL%" == "" (
    echo No build tool-chain found in PATH:
    echo PATH="%PATH%"
    goto errorenv
)

set projectpath=%1
IF %projectpath:~-1%==/ SET projectpath=%projectpath:~0,-1%
FOR %%P in ("%projectpath%") DO (
    set projectname=%%~nP
)
echo Building '%projectpath%' into '%projectname%'

mkdir %projectname%
cd %projectname%

call %USERPROFILE%\qmake.bat "%projectpath%"
echo Using %MAKETOOL%
%MAKETOOL% clean
%MAKETOOL%

echo Project '%projectname%' built successfully

exit 0

:errorargs
exit 1

:errorenv
exit 2