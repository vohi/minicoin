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

echo "Using Qt in %cd%"
set PATH="%CD%\bin;%PATH%"

bin\qtdiag
bin\uic --version
bin\moc --version
bin\qmake -query
