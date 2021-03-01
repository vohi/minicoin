@echo off
set "MINICOIN_PROJECT_DIR=%cd%"

setlocal
set "minicoin_dir=%~dp0"
set error=0
cd "%minicoin_dir%"

if "%1" == "update" (
    shift
    goto :update
)
if "%1" == "help" (
    goto :help
)

call vagrant %*
set error=%errorlevel%
goto :end

:update
git fetch --all --tags 2> NUL > NUL
if %errorlevel% == 0 (
    if "%1" == "" (
        FOR /F "tokens=* USEBACKQ" %%F IN (`git describe --abbrev=0`) DO set "minicoin_version=%%F"
    ) else (
        set "minicoin_version=%1"
    )
) else (
    >&2 echo Failed to fetch tags, can't update minicoin!
)
if not "%minicoin_version%" == "" (
    echo Checking out version %minicoin_version%
    git stash > NUL
    git checkout %minicoin_version% > NUL
)
goto :end

:help
type help.txt
goto :end

:end
cd "%MINICOIN_PROJECT_DIR%"
set MINICOIN_PROJECT_DIR=
exit /B %error%
