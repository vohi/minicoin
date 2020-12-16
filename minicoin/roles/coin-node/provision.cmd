@echo off
setlocal ENABLEDELAYEDEXPANSION
call C:\minicoin\util\parse-opts.cmd %*

2>NUL cd /minicoin/roles/coin-node/coin
if errorlevel 1 (
    >&2 echo Can't find coin scripts
    exit /b 1
)

type hosts >> C:\Windows\system32\drivers\etc\hosts

echo Provisioning with template '!PARAM_template!'
cd provisioning\!PARAM_template!

if errorlevel 1 (
    >&2 echo Can't find coin template '!PARAM_template!'
    exit /b 2
)

FOR /f %%s in ('dir *.ps1 /B /O:N') do set "PSSCRIPTS=!PSSCRIPTS! %%s"

if defined PARAM_runlist (
    set RUNLIST=!PARAM_runlist!
) else (
    set RUNLIST=
)
if defined PARAM_skiplist (
    set SKIPLIST=!PARAM_skiplist!
) else (
    set SKIPLIST=qnx_700 install_telegraf install-mcuxpresso install-virtualbox emsdk squish squish-coco
)

FOR %%s IN (%PSSCRIPTS%) DO (
    set "step=%%s"
    set "step=!step:*-=!"
    set "step=!step:.ps1=!"
    set skip=
    for %%a IN (%SKIPLIST%) DO (
        if %%a==!step! set skip=1
    )
    for %%a IN (%RUNLIST%) DO (
        if %%a==!step! set skip=
    )

    if defined skip (
        echo -- Skipping '%%s'
    ) else (
        echo ++ Executing '%%s'
        powershell -File "%%s"
    )
)
