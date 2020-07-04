@echo off
setlocal ENABLEDELAYEDEXPANSION
setlocal EnableExtensions

call C:\minicoin\util\parse-opts.cmd %*

set PACKAGE=!PARAM_mutagen_install!
set USERNAME=!POSITIONAL[2]!
set HOST=!PARAM_mutagen_host_ip!


echo Installing mutagen from !PACKAGE!
rmdir /S/Q c:\mutagen
mkdir c:\mutagen
cd c:\mutagen
tar -xzf !PACKAGE!

echo Adding !HOST! to list of known hosts
ssh-keyscan -H !HOST! >> c:\Users\vagrant\.ssh\known_hosts

echo Starting mutagen daemon
c:\mutagen\mutagen daemon start
c:\mutagen\mutagen daemon register

for /L %%i in (0, 1, !PARAM_alpha[#]!) do (
    mkdir !PARAM_beta[%%i]!
    c:\mutagen\mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin !USERNAME!@!HOST!:!PARAM_alpha[%%i]! !PARAM_beta[%%i]!
)

echo Established mutagen sync points:
c:\mutagen\mutagen sync list
