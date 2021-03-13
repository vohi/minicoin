@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call c:\minicoin\util\parse-opts.cmd %*

echo Job works on '%JOBDIR%'

if defined FLAG_echo (
    echo All arguments: %*
    echo Named:
    for %%p in (!PARAMS[@]!) do (
        if NOT "!PARAM_%%p[1]!" == "" (
            echo - %%p[!PARAM_%%p[#]!]
            for /L %%i in (0, 1, !PARAM_%%p[#]!) do echo   - !PARAM_%%p[%%i]!
        ) else (
            echo - %%p: !PARAM_%%p!
        )
    )
    echo Positional:
    set /A end=!POSITIONAL[#]!-1
    for /L %%i in (0, 1, !end!) do echo - !POSITIONAL[%%i]!
    echo Flags:
    for %%f in (!FLAGS[@]!) do echo - %%f

    exit /B 0
)

if defined FLAG_debug (
    echo Running parse-opts-test
    cd c:\minicoin\tests
    call parse-opts-test.cmd
    exit /B %errorcode%
)

echo Hello runner^^!
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"
echo Args received:
set errorcode=0
for %%i in (%*) DO (
    ECHO '%%i'
    if "%%i" == "error" (
        set errorcode=42
    )
)

echo Testing stdout and stderr
for %%I in (1,2,3) do (
    echo - stdout %%I
    >&2 echo - stderr %%I
    waitfor something /T 1 2> NUL
)

if "!errorcode!" == "0" (
    echo Exiting without error
) else (
    >&2 echo Exiting with error code !errorcode!
)
exit /B !errorcode!
