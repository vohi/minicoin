@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call c:\minicoin\util\parse-opts.cmd %*

if defined FLAG_debug (
    echo Running parse-opts-test
    cd c:\minicoin\tests
    call parse-opts-test.cmd
    exit /B %errorcode%
)

echo Hello runner!
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"
echo Args received:
set errorcode=0
for %%i in (%*) DO (
    ECHO '%%i'
    if "%%i" == "error" (
        set errorcode=1
        >&2 echo Exiting with error code %errorcode%
    )
)

>&2 echo Testing stderr
exit /B %errorcode%
