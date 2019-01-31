@echo off
IF "%~1" == "" (
    echo "No project specified"
    goto errorargs
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
    echo "No build tool-chain found in PATH"
    goto errorenv
)

set PATH=%PATH%;%USERPROFILE%\qt5-build\qtbase\bin

cd %1
qmake || exit /B 3
%MAKE% clean || exit /B 4
%MAKE% || exit /B 5

echo "project built successfully"

exit 0

errorargs:
exit 1

errorenv:
exit 2