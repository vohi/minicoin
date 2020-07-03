@echo off
setlocal ENABLEDELAYEDEXPANSION

call C:\minicoin\util\parse-opts.cmd %*

echo All arguments: %*

set USERNAME=!POSITIONAL[2]!
set HOST=!PARAM_mutagen_host_ip!

echo Adding !HOST! to list of known hosts
ssh-keyscan -H !HOST! >> c:\Users\vagrant\.ssh\known_hosts

echo Starting mutagen daemon
c:\mutagen\mutagen daemon start
c:\mutagen\mutagen daemon register

for /L %%i in (0, 1, !PARAM_alphas[#]!) do (
    echo Syncing !USERNAME!@!HOST!:!PARAM_alphas[%%i]! to !PARAM_betas[%%i]!
    c:\mutagen\mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin !USERNAME!@!HOST!:!PARAM_alphas[%%i]! !PARAM_betas[%%i]!
)

echo Established mutagen sync points:
c:\mutagen\mutagen sync list
