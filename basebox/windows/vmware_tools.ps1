Mount-DiskImage C:\Users\vagrant\vmware_tools.iso
$volume = (Get-DiskImage -ImagePath C:\Users\vagrant\vmware_tools.iso | Get-Volume) 
$drive = ($volume).DriveLetter
Write-Host "Installing VMware Tools from ${drive}:"
& ${drive}:\VMwareToolsUpgrader.exe
Start-Sleep -Seconds 45
Dismount-DiskImage C:\Users\vagrant\vmware_tools.iso
Remove-Item -Path C:\Users\vagrant\vmware_tools.iso
