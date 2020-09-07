@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
call \minicoin\util\parse-opts.cmd %*

echo "Starting"

for %%F in ("%0") do set "dirname=%%~dpF"
if exist "%dirname%\qtaccount.ini" (
    if not exist "%USERPROFILE%\AppData\Roaming\Qt\qtaccount.ini" (
        echo Installing qtaccount.ini file from "%dirname%"
        if not exist "%USERPROFILE%\AppData\Roaming\Qt" mkdir "%USERPROFILE%\AppData\Roaming\Qt"
        copy "%dirname%\qtaccount.ini" "%USERPROFILE%\AppData\Roaming\Qt\qtaccount.ini"
    )
) else (
    echo qtaccount.ini file not found in "%dirname%", aborting
    exit /b 3
)

echo "Calling cmake"

cmake -DINSTALL_ROOT=Qt %* -P "%dirname%\install-online.cmake"

if not exist "Qt\6.0.0" (
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
