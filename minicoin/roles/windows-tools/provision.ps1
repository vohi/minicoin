$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$Name = "NoAutoUpdate"
$value = "1"

IF(!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
} ELSE {
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
}

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
ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }
.\chocolatey feature disable -n=allowGlobalConfirmation

psexec -accepteula

$oldpath += ";c:\Users\vagrant\bin;c:\Python27;c:\Python27\Scripts;c:\Strawberry\perl\bin;c:\Program Files\CMake\bin"
[Environment]::SetEnvironmentVariable("PATH", $oldpath, [System.EnvironmentVariableTarget]::Machine)

refreshenv