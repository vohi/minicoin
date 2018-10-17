# allow Powershell scripts to provision
Set-ExecutionPolicy -ExecutionPolicy Unrestricted

# remove all of the metro apps
Get-AppXPackage -AllUsers | Remove-AppXPackage
 
# remove log files
Get-Childitem "C:\Windows\Logs\dosvc" | Remove-Item -Verbose
 
# disables the system restore feature
Disable-ComputerRestore c:
 
# disable hibernation
powercfg -h off
