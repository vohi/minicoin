function UpdateRegistry {
    param (
        [parameter(Mandatory=$true)]
        [String]$Path,
        [parameter(Mandatory=$true)]
        [String]$Name,
        [String]$Text,
        [String]$Number
    )

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    if ($Text) {
        New-ItemProperty -Path $Path -Name $Name -Value $Text -PropertyType String -Force | Out-Null
    } elseif ($Number) {
        New-ItemProperty -Path $Path -Name $Name -Value $Number -PropertyType DWORD -Force | Out-Null
    } else {
        New-ItemProperty -Path $Path -Name $Name | Out-Null
    }
}

UpdateRegistry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Number 1
UpdateRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name "DefaultUserName" -Text "vagrant"
UpdateRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name "DefaultPassword" -Text "vagrant"
UpdateRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name "AutoAdminLogon" -Text "1"

UpdateRegistry -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Text "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null

UpdateRegistry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Number 1
UpdateRegistry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableEnhancedNotifications" -Number 1
UpdateRegistry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Number 1
UpdateRegistry -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Number 1
UpdateRegistry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Number 0
UpdateRegistry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Number 0
UpdateRegistry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "NoToastApplicationNotification" -Number 1
UpdateRegistry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "NoToastApplicationNotificationOnLockScreen" -Number 1
