Install-PackageProvider Nuget -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name PackageManagement -Force

Install-PackageProvider chocolatey -Forcebootstrap
Set-PackageSource -Name Chocolatey -Trusted
