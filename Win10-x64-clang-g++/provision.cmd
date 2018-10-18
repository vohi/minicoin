REM Create a link to the mounted host folder in the user's home directory
mklink /D %HOMEPATH%\%1 \\VBOXSRV\%1

REM Install PowerShell Gallery and Package Management
powershell -command "${$'Install-PackageProvider' Nuget -Force}"
powershell -command "${$'Install-Module' –Name PowerShellGet –Force}"
powershell -command "${$'Set-PSRepository' -Name PSGallery -InstallationPolicy Trusted}"
powershell -command "${$'Install-Module' -Name PackageManagement -Force}"

REM Install Visual Studio Code
powershell -command "${$'Install-Module' -Name vscode}"

echo "Hello %1!"
