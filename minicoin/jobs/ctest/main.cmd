@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

call C:\minicoin\util\parse-opts.cmd %*
call C:\minicoin\util\discover-make.cmd

if NOT DEFINED JOBDIR (
    >&2 echo Error: path to host clone of Qt is required!
    exit /B 1
)

if NOT "!PARAM_build!"=="" (
    echo "Starting from !PARAM_build!"
    cd %USERPROFILE%/!PARAM_build!
) else (
    cd C:\
    set find_build=1
)

:down
for /F "tokens=1 delims=\" %%a in ("!JOBDIR!") do (
    set "segment=%%a"
)
if NOT "%segment%"=="C:" (
    if DEFINED find_build (
        if "!PARAM_build!"=="" (
            set "buildsegment=%segment%-build"
        ) else (
            set "buildsegment=!PARAM_build!"
        )
        if exist "%USERPROFILE%\!buildsegment!" (
            cd "%USERPROFILE%\!buildsegment!"
            set find_build=
        )
    )
    if NOT DEFINED find_build (
        if exist %segment% cd %segment%
    )
)
set "OLDJOBDIR=!JOBDIR!"
set JOBDIR=!JOBDIR:*%segment%\=!
if "!OLDJOBDIR!"=="!JOBDIR!" goto :there
if NOT "!JOBDIR!"=="" goto :down

:there

SET error=0
set TESTARGS=!PARAM_testargs!

echo Running ctest !PASSTHROUGH[@]! in %cd%
ctest "!PASSTHROUGH[@]!"
