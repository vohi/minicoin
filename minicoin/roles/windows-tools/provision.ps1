param (
    [String[]]$Packages
)

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

if (!$Packages) {
    $Packages = ( "notepadplusplus", "git", "pstools",
                  "strawberryperl", "python2",
                  "cmake", "ninja" )
} else {
    $Packages = $Packages.split(",")
}

chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) {
    $measurement = Measure-Command {
        & chocolatey install --no-progress --limitoutput -y $p | Out-Default
    }
    
    if ($measurement.TotalMinutes -lt 1) {
        $duration = "$($measurement.TotalSeconds) Seconds"
    } else {
        $duration = $measurement.ToString("hh\:mm\:ss")
    }
    Write-Host "Installation of $p completed after $duration"
}
chocolatey feature disable -n=allowGlobalConfirmation

psexec -nobanner -accepteula | Out-Null

$oldpath += ";c:\Users\vagrant\bin;c:\Python27;c:\Python27\Scripts;c:\Strawberry\perl\bin;c:\Program Files\CMake\bin"
[Environment]::SetEnvironmentVariable("PATH", $oldpath, [System.EnvironmentVariableTarget]::Machine)

refreshenv
