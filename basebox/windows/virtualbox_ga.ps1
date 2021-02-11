Mount-DiskImage C:\Users\vagrant\VBoxGuestAdditions.iso
$volume = (Get-DiskImage -ImagePath C:\Users\vagrant\VBoxGuestAdditions.iso | Get-Volume) 
$drive = ($volume).DriveLetter
Write-Host "Installing Guest Additions from ${drive}:"
& ${drive}:\VBoxWindowsAdditions.exe
Start-Sleep -Seconds 45
Dismount-DiskImage C:\Users\vagrant\VBoxGuestAdditions.iso
Remove-Item -Path C:\Users\vagrant\VBoxGuestAdditions.iso
