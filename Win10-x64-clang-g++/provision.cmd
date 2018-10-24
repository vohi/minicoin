REM Optional Create a link to the mounted host folder in the user's home directory
REM mklink /D %HOMEPATH%\%1 \\VBOXSRV\%1

echo "Installing PowerShell Gallery and Package Management (takes a long time)"
powershell \\VBOXSRV\vagrant\provision-packagemanager.ps1

echo "Installing build tools"
powershell \\VBOXSRV\vagrant\provision-vcpp.ps1

echo "Installing Git"
powershell \\VBOXSRV\vagrant\provision-choco.ps1

echo "Installing Tools"
powershell \\VBOXSRV\vagrant\provision-tools.ps1

echo "Copying env helper scripts"
powershell \\VBOXSRV\vagrant\provision-devenv.ps1

echo "Please reboot the VM and let it install updates..."
