@echo off

echo Hello runner!
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