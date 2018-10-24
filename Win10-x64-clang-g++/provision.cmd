REM Optional Create a link to the mounted host folder in the user's home directory
REM mklink /D %HOMEPATH%\%1 \\VBOXSRV\%1

REM Install PowerShell Gallery and Package Management
echo "Installing package manager"
powershell \vagrant\provision-packagemanager.ps1

REM Install Visual Studio Code
echo "Installing build tools"
powershell \vagrant\provision-vcpp.ps1

echo "Hello %1!"
