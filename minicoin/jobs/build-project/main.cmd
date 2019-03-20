@echo off
SETLOCAL

IF "%~1" == "" (
    echo No project specified!
    goto errorargs:
)

for %%C in (nmake.exe jom.exe mingw32-make.exe) do set %%C=%%~$PATH:C

if NOT "%mingw32-make.exe%" == "" (
    set MAKE=mingw32-make.exe
) else if NOT "%jom.exe%" == "" (
    set MAKE=jom.exe
) else if NOT "%nmake.exe%" == "" (
    set MAKE=nmake.exe
)

if "%MAKE%" == "" (
    echo No build tool-chain found in PATH:
    echo PATH="%PATH%"
    goto errorenv:
)

set PATH=%PATH%;%USERPROFILE%\qtbase-build\bin

set projectpath=%1
IF %projectpath:~-1%==/ SET projectpath=%projectpath:~0,-1%
FOR %%P in ("%projectpath%") DO (
    set projectname=%%~nP
)
echo Building '%projectpath%' into '%projectname%'

mkdir %projectname%
cd %projectname%

%USERPROFILE%\qmake.bat "%projectpath%" || exit /B 3
%MAKE% clean || exit /B 4
%MAKE% || exit /B 5

echo Project '%projectname%' built successfully

exit 0

errorargs:
exit 1

errorenv:
exit 2