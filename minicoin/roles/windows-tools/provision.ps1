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
        New-ItemProperty -Path $Path -Name $Name -Value $Text -PropertyType String -FORCE | Out-Null
    } elseif ($Number) {
        New-ItemProperty -Path $Path -Name $Name -Value $Number -PropertyType DWORD -FORCE | Out-Null
    } else {
        New-ItemProperty -Path $Path -Name $Name | Out-Null
    }
}

UpdateRegistry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Number 1
UpdateRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name "DefaultUserName" -Text "vagrant"
UpdateRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name "DefaultPassword" -Text "vagrant"
UpdateRegistry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name "AutoAdminLogon" -Text "1"

IF(!(Test-Path C:\Users\vagrant\bin)) {
    New-Item -Type Directory -Path C:\Users\vagrant\bin | Out-Null
}

$ChocoInstallPath = "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

if (!(Test-Path $ChocoInstallPath)) {
    write-host "Install Chocolatey . . . "
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | out-null
    write-host "END Installing Chocolatey!"
} else {
    write-host "Upgrade Chocolatey . . . "
    cd $ChocoInstallPath
    .\choco upgrade chocolatey
    write-host "END Upgrade Chocolatey!"
}

$oldpath = [Environment]::GetEnvironmentVariable("PATH",[System.EnvironmentVariableTarget]::Machine)

cd $ChocoInstallPath

$packages = ( "notepadplusplus", "git", "pstools",
              "strawberryperl", "python2",
              "cmake", "ninja" )

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\choco install --no-progress -y --timeout 600 $p }
.\chocolatey feature disable -n=allowGlobalConfirmation

psexec -nobanner -accepteula | Out-Null

$oldpath += ";c:\Users\vagrant\bin;c:\Python27;c:\Python27\Scripts;c:\Strawberry\perl\bin;c:\Program Files\CMake\bin"
[Environment]::SetEnvironmentVariable("PATH", $oldpath, [System.EnvironmentVariableTarget]::Machine)

refreshenv

# set PowerShell as the default log-in shell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
