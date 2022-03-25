. "c:\opt\minicoin\util\install_helper.ps1"

chocolatey feature enable -n=allowGlobalConfirmation

$packages = ( 
                "windows-sdk-10.0",
                "python3",
                "nodejs",
                "gperf",
                "winflexbison"
            )

ForEach ( $p in $packages ) {
    $measurement = Measure-Command {
        Run-KeepAlive -ScriptBlock {
            param($package)
            write-host "Installing $package"
            & chocolatey install --no-progress --limitoutput -y $package | Out-Default
            write-host "Done Installing $package"
        } -Arguments $p -HeartBeat 30
    }
    $duration = ""
    if ($measurement.TotalMinutes -lt 1) {
        $duration = "$($measurement.TotalSeconds) Seconds"
    } else {
        $duration = $measurement.ToString("hh\:mm\:ss")
    }
    Write-Host "Installation of $p completed after $duration"
}
chocolatey feature disable -n=allowGlobalConfirmation

$path = [Environment]::GetEnvironmentVariable('PATH','user')
[Environment]::SetEnvironmentVariable("PATH", "$path;C:\Python310\Scripts;C:\Program Files\nodejs", 'user')
[Environment]::SetEnvironmentVariable("WindowsSdkVersion", "10.0.22000.0", 'user')
[Environment]::SetEnvironmentVariable("WINDOWSSDKDIR", "C:\Program Files (x86)\Microsoft SDKs\Windows Kits\10\ExtensionSDKs", 'user')

refreshenv

C:\Python310\Scripts\pip.exe install html5lib
