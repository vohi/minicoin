@echo off

setlocal enabledelayedexpansion
set "oldpwd=%cd%"
cd %TEMP%

vagrant --version 2> NUL > NUL
if !errorlevel! NEQ 0 (
    echo vagrant not found, installing
    choco --version 2> NUL > NUL
    if !errorlevel! NEQ 0 (
        echo Chocolatey not found, please install manually
        exit /B 1
    )

    VBoxManage --version 2> NUL > NUL
    if !errorlevel! NEQ 0 (
        echo VirtualBox not found
        choco install --confirm virtualbox
        if !errorlevel! NEQ 0 if !errorlevel! NEQ 1641 if !errorlevel! NEQ 3010 (
            echo VirtualBox installation failed, aborting installation. Please retry.
            exit /B 1
        )
        call refreshenv > NUL

        FOR /F "tokens=1 delims=r USEBACKQ" %%F IN (`VBoxManage --version`) DO set vbox_version=%%F
        powershell -Command "(new-object net.webclient).DownloadFile('https://download.virtualbox.org/virtualbox/!vbox_version!/Oracle_VM_VirtualBox_Extension_Pack-!vbox_version!.vbox-extpack', 'Oracle_VM_VirtualBox_Extension_Pack-!vbox_version!.vbox-extpack')"
        echo yes | VBoxManage.exe extpack install --accept-license=yes Oracle_VM_VirtualBox_Extension_Pack-!vbox_version!.vbox-extpack
    ) else (
        FOR /F "tokens=* USEBACKQ" %%F IN (`VBoxManage --version`) DO echo VirtualBox version %%F found
    )

    choco install --confirm vagrant
    if !errorlevel! NEQ 0 if !errorlevel! NEQ 1641 if !errorlevel! NEQ 3010 (
        echo vagrant installation failed, aborting installation. Please retry.
        exit /B 1
    )
    call refreshenv > NUL
) else (
    FOR /F "tokens=* USEBACKQ" %%F IN (`vagrant --version`) DO echo Vagrant version %%F found
)

mutagen version 2> NUL > NUL
if !errorlevel! NEQ 0 (
    echo Mutagen not found, installing
    set "mutagen_version_good=0.16.2"
    set "mutagen_filename=mutagen_windows_amd64_v!mutagen_version_good!.zip"

    powershell -Command "(new-object net.webclient).DownloadFile('https://github.com/mutagen-io/mutagen/releases/download/v!mutagen_version_good!/!mutagen_filename!', '!mutagen_filename!')"
    powershell -Command "Expand-Archive -Force !mutagen_filename! c:\programdata\mutagen"
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('PATH', 'User') + ';C:\programdata\mutagen', 'User')"

    call refreshenv > NUL
) else (
    FOR /F "tokens=* USEBACKQ" %%F IN (`mutagen version`) DO echo Mutagen version %%F found
)

where minicoin.cmd 2> NUL > NUL
if !errorlevel! NEQ 0 (
    echo Adding %~dp0%minicoin to the PATH
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('PATH', 'User') + ';%~dp0%minicoin', 'User')"
    call refreshenv > NUL
)

cd %oldpwd%
call minicoin update

endlocal
call refreshenv 2> NUL > NUL

echo.
echo Minicoin set up!
call minicoin list

if not defined minicoin_key (
    echo No minicoin_key set, some boxes will not be available!
)
