REM Optional Create a link to the mounted host folder in the user's home directory
REM mklink /D %HOMEPATH%\%1 \\VBOXSRV\%1

echo "Installing PowerShell Gallery and Package Management"
powershell \\VBOXSRV\vagrant\provision-packagemanager.ps1

echo "Installing build tools"
powershell \\VBOXSRV\vagrant\provision-vcpp.ps1

echo "Installing Git"
powershell \\VBOXSRV\vagrant\provision-git.ps1

echo "Installing Perl"
powershell \\VBOXSRV\vagrant\provision-perl.ps1

echo "Installing Python 2"
powershell \\VBOXSRV\vagrant\provision-python2.ps1

echo "Installing LLVM and Clang"
powershell \\VBOXSRV\vagrant\provision-llvm.ps1

echo "Installing Tools"
powershell \\VBOXSRV\vagrant\provision-tools.ps1
