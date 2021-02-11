Set-PSRepository -InstallationPolicy Trusted -Name PSGallery
Install-Module PSWindowsUpdate
Get-WindowsUpdate
Install-WindowsUpdate -AcceptAll
