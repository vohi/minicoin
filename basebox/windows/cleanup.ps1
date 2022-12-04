$ErrorActionPreference = "SilentlyContinue"
net stop wuauserv

$tempfolders = @( "C:\Windows\Prefetch\*",
                  "C:\Users\*\Appdata\Local\Temp\*",
                  "C:\Windows\SoftwareDistribution\Downloads\*",
                  "C:\Windows\Temp\*"
                )

function Set-RegistryKey
{
    param(
        [string]$Path,
        [string]$Key,
        [int]$Value
    )
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Key -Value $Value -Type DWORD -Force | Out-Null
}

Remove-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell

Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Key "DisableAntiSpyware" -Value 1
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Key "DisableEnhancedNotifications" -Value 1
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Key "DisableNotifications" -Value 1
Set-RegistryKey -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Key "DisableNotificationCenter" -Value 1
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Key "ScoobeSystemSettingEnabled" -Value 0
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Key "ToastEnabled" -Value 0
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Key "NoToastApplicationNotification" -Value 1
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Key "NoToastApplicationNotificationOnLockScreen" -Value 1

choco upgrade --confirm chocolatey
choco install --confirm sdelete

# doesn't block, so no point in running this here
# cleanmgr /sagerun:1

Remove-Item $tempfolders -force -recurse
Optimize-Volume -DriveLetter C -Defrag
sdelete64 -z c:

exit 0
