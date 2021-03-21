@echo off

setlocal enabledelayedexpansion
set "oldpwd=%cd%"
cd %TEMP%

vagrant --version 2> NUL > NUL
if NOT !errorlevel! == 0 (
    echo vagrant not found, installing
    choco --version 2> NUL > NUL
    if NOT !errorlevel! == 0 (
        echo Chocolatey not found, please install manually
        exit /B 1
    )

    VBoxManage --version 2> NUL > NUL
    if NOT !errorlevel! == 0 (
        echo VirtualBox not found
        choco install --confirm virtualbox
        call refreshenv

        powershell -Command "(new-object net.webclient).DownloadFile('https://download.virtualbox.org/virtualbox/6.1.18/Oracle_VM_VirtualBox_Extension_Pack-6.1.18.vbox-extpack', 'Oracle_VM_VirtualBox_Extension_Pack-6.1.18.vbox-extpack')"
        echo yes | VBoxManage.exe extpack install --accept-license=yes Oracle_VM_VirtualBox_Extension_Pack-6.1.18.vbox-extpack
    ) else (
        FOR /F "tokens=* USEBACKQ" %%F IN (`VBoxManage --version`) DO echo VirtualBox version %%F found
    )

    choco install --confirm vagrant
    call refreshenv > NUL
) else (
    FOR /F "tokens=* USEBACKQ" %%F IN (`vagrant --version`) DO echo Vagrant version %%F found
)

mutagen version 2> NUL > NUL
if NOT !errorlevel! == 0 (
    echo Mutagen not found, installing

    powershell -Command "(new-object net.webclient).DownloadFile('https://github.com/mutagen-io/mutagen/releases/download/v0.11.8/mutagen_windows_amd64_v0.11.8.zip', 'mutagen_windows_amd64_v0.11.8.zip')"
    powershell -Command "Expand-Archive -Force mutagen_windows_amd64_v0.11.8.zip c:\programdata\mutagen"
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('PATH', 'User') + ';C:\programdata\mutagen', 'User')"

    call refreshenv > NUL
) else (
    FOR /F "tokens=* USEBACKQ" %%F IN (`mutagen version`) DO echo Mutagen version %%F found
)

where minicoin.cmd 2> NUL > NUL
if NOT !errorlevel! == 0 (
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
