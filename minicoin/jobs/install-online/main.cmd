@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
call \minicoin\util\parse-opts.cmd %*

for %%F in ("%0") do set "dirname=%%~dpF"
if exist "%dirname%\qtaccount.ini" (
    if not exist "%USERPROFILE%\AppData\Roaming\Qt\qtaccount.ini" (
        echo Installing qtaccount.ini file from "%dirname%" into %USERPROFILE%
        if not exist "%USERPROFILE%\AppData\Roaming\Qt" mkdir -p "%USERPROFILE%\AppData\Roaming\Qt"
        copy "%dirname%\qtaccount.ini" "%USERPROFILE%\AppData\Roaming\Qt\qtaccount.ini"
    )
) else (
    echo qtaccount.ini file not found in "%dirname%", aborting
    exit /b 3
)

cmake -DINSTALL_ROOT=!PARAM_install_root! -DPACKAGE=!PARAM_package! -P "%dirname%\install-online.cmake"

if %errorlevel% NEQ 0 (
    >&2 echo Installation failed, aborting
    exit /b 4
)

cd Qt\6.0.0

for /D %%D in (*) do (
    if not "%%D" == "Src" (
        cd %%D
        echo "Using Qt in %cd%"
        set PATH="%CD%\bin;%PATH%"
        goto :RUNTEST

    )
)

:RUNTEST

qtdiag
uic --version
moc --version
qmake --query
