param (
    [String[]]$Version = "2022"
)

$variables = @{
    "2019" = @{
        ChannelId="VisualStudio.16.Release"
        InstallDir="C:\Program Files (x86)\Microsoft Visual Studio\2019"
    }
    "2022" = @{
        ChannelId="VisualStudio.17.Release"
        InstallDir="C:\Program Files (x86)\Microsoft Visual Studio\2022"
    }
}

if (!$variables.ContainsKey("$Version")) {
    $keys = $variables.keys
    Write-Error "Version '${Version}' is not supported by this provisioning script, use one of: ${keys}"
    exit 1
}

$channelId=$variables[$Version].ChannelId
$installDir=$variables[$Version].InstallDir

. "c:\opt\minicoin\util\install_helper.ps1"

$packages = (
    "visualstudio${Version}-workload-vctools"
)

& cmd /c "winrm set winrm/config/winrs @{MaxMemoryPerShellMB=`"2147483647`"}"

chocolatey feature enable -n=allowGlobalConfirmation
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

$vc_workloads = (
    "Microsoft.VisualStudio.Component.VC.ATL",
    "Microsoft.VisualStudio.Component.VC.ATLMFC"
)

ForEach ( $p in $vc_workloads ) {
    $measurement = Measure-Command {
        Run-KeepAlive -ScriptBlock {
            param($package)
            write-host "Installing Visual Studio component $package"
            & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --norestart --quiet --productId Microsoft.VisualStudio.Product.BuildTools --channelId $channelId --add $package | Out-Default
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

refreshenv

Invoke-CmdScript "${InstallDir}\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

[Environment]::SetEnvironmentVariable("PATH", $env:Path, 'user')
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, 'user')
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, 'user')
[Environment]::SetEnvironmentVariable("VSINSTALLDIR", $installDir, 'user')

refreshenv
