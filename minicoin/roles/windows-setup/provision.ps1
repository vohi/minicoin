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
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force | Out-Null

Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Key "DisableAntiSpyware" -Value 1
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Key "DisableEnhancedNotifications" -Value 1
Set-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Key "DisableNotifications" -Value 1
Set-RegistryKey -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Key "DisableNotificationCenter" -Value 1
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Key "ScoobeSystemSettingEnabled" -Value 0
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Key "ToastEnabled" -Value 0
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Key "NoToastApplicationNotification" -Value 1
Set-RegistryKey -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Key "NoToastApplicationNotificationOnLockScreen" -Value 1
