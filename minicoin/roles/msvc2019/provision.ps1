. "c:\opt\minicoin\util\install_helper.ps1"

$packages = ( 
    "visualstudio2019-workload-vctools"
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
            & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --norestart --quiet --productId Microsoft.VisualStudio.Product.BuildTools --channelId VisualStudio.16.Release --add $package | Out-Default
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

function Invoke-CmdScript {
    param(
        [String] $scriptName
    )
    $cmdLine = """$scriptName"" $args & set"
    & $Env:SystemRoot\system32\cmd.exe /c $cmdLine |
      Select-String '^([^=]*)=(.*)$' | ForEach-Object {
        $varName = $_.Matches[0].Groups[1].Value
        $varValue = $_.Matches[0].Groups[2].Value
        Set-Item env:$varName -Value $varValue
    }
}

Invoke-CmdScript "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

[Environment]::SetEnvironmentVariable("PATH", $env:Path, 'user')
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, 'user')
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, 'user')
[Environment]::SetEnvironmentVariable("VSINSTALLDIR", "C:\Program Files (x86)\Microsoft Visual Studio\2019", 'user')

refreshenv
