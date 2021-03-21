@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
call \minicoin\util\parse-opts.cmd %*

where cmake > NUL 2> NUL
if %errorlevel% NEQ 0 (
    choco install --no-progress --no-progress --limitoutput -y cmake
    set "PATH=%PATH%;c:\Program Files\CMake\bin"
)

set "jobpath=%~dp0"
if exist "Documents\qtaccount.ini" (
    echo Installing qtaccount.ini file from %cd%
    if not exist "%USERPROFILE%\AppData\Roaming\Qt" mkdir "%USERPROFILE%\AppData\Roaming\Qt"
    copy "Documents\qtaccount.ini" "%USERPROFILE%\AppData\Roaming\Qt\qtaccount.ini"
) else (
    echo qtaccount.ini file not found in "%cd%", aborting
    exit /b 3
)

set "INSTALL_ROOT=!PARAM_install_root!"
if not defined INSTALL_ROOT set "INSTALL_ROOT=Qt"

set "cmake_params=-DINSTALL_ROOT=!PARAM_install_root! -DPACKAGE=!PARAM_package!"
if defined PARAM_search set "cmake_params=%cmake_params% -DSEARCH=!PARAM_search!"

cmake %cmake_params% -P "%jobpath%\install-online.cmake"

set result=%errorlevel%
if defined PARAM_search exit /B %result%
if %result% NEQ 0 (
    >&2 echo Installation failed, aborting
    exit /b 4
)

cd %INSTALL_ROOT%

for /f "tokens=*" %%Q in ('dir /b /s /od moc.exe') do set "qtinstall=%%Q"
for %%Q in ("%qtinstall%") do set "qtinstall=%%~dpQ"

if not defined qtinstall (
    >&2 echo moc not found, installation failed!
    exit 5
)

cd !qtinstall!
:GOUP
if not exist "%CD%\bin" (
    cd ..
    goto :GOUP
)

echo Using Qt in %cd%
set PATH="%CD%\bin;%PATH%"

bin\qtdiag
bin\uic --version
bin\moc --version
bin\qmake -query

if exist bin\qmake.exe (
    echo @echo off > %USERPROFILE%\bin\qmake.bat
    echo SET "PATH=%cd%\bin;%%PATH%%" >> %USERPROFILE%\bin\qmake.bat
    echo call %cd%\bin\qmake %%* >> %USERPROFILE%\bin\qmake.bat
)
if exist bin\qt-cmake.bat (
    echo @echo off > %USERPROFILE%\bin\qt-cmake.bat
    echo SET "PATH=%cd%\bin;%%PATH%%" >> %USERPROFILE%\bin\qt-cmake.bat
    echo call %cd%\bin\qt-cmake %%* >> %USERPROFILE%\bin\qt-cmake.bat
)
