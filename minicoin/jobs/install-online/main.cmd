@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
call \minicoin\util\parse-opts.cmd %*

if exist "Documents\qtaccount.ini" (
    echo Installing qtaccount.ini file from "%cd%" into %USERPROFILE%
    if not exist "%USERPROFILE%\AppData\Roaming\Qt" mkdir -p "%USERPROFILE%\AppData\Roaming\Qt"
    copy "Documents\qtaccount.ini" "%USERPROFILE%\AppData\Roaming\Qt\qtaccount.ini"
) else (
    echo qtaccount.ini file not found in "%cd%", aborting
    exit /b 3
)

where cmake > NUL 2> NUL
if %errorlevel% NEQ 0 (
    choco install --no-progress --no-progress --limitoutput -y cmake
    set "PATH=%PATH%;c:\Program Files\CMake\bin"
)

set "INSTALL_ROOT=!PARAM_install_root!"
if not defined INSTALL_ROOT set "INSTALL_ROOT=Qt"

for %%F in ("%0") do set "jobname=%%~dpF"
cmake -DINSTALL_ROOT=!PARAM_install_root! -DPACKAGE=!PARAM_package! -P "%jobname%\install-online.cmake"

if %errorlevel% NEQ 0 (
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
