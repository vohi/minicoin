@echo off
setlocal ENABLEDELAYEDEXPANSION ENABLEEXTENSIONS
set CURDIR=%CD%
set ARGS=%*
set POSITIONAL=

call :parseargs %ARGS%
if errorlevel 1 exit /b
set ARGS=%POSITIONAL%
call :go
cd %CURDIR%
exit /b

:parseargs
if /i "%~1" == "" exit /b

if /i "%~1" == "--coin-root" (
    set COINROOT=%~2
    shift
) else if /i "%~1" == "--template" (
    set TEMPLATE=%~2
    shift
) else (
    set POSITIONAL=!POSITIONAL! %~1
)

:loopargs
  shift
  goto :parseargs

REM End of parameter parsing

:go

echo Provisioning from '%COINROOT%' using template '%TEMPLATE%'

2>NUL cd %COINROOT%/Provisioning
if errorlevel 1 (
    echo '%COINROOT%/provisioning' does not exist
    exit /b
)

2>NUL cd %TEMPLATE%
if errorlevel 1 (
    echo No coin template '%TEMPLATE%'
    exit /b
)

FOR /f %%s in ('dir *.ps1 /B /O:N') do set PSSCRIPTS=!PSSCRIPTS! %%s

FOR %%s IN (%PSSCRIPTS%) DO (
    echo ++ Executing '%%s %ARGS%'
    powershell -File "%%s" %ARGS%
)