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

cd $ChocoInstallPath

$packages = ( "notepadplusplus", "git",
              "strawberryperl", "python2" )

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }
.\chocolatey feature disable -n=allowGlobalConfirmation

[Environment]::SetEnvironmentVariable("PATH", `
  "c:\strawberry\perl\bin;c:\Python27;c:\program files\git\cmd", `
  [System.EnvironmentVariableTarget]::User)
