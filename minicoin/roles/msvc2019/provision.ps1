$packages = ( 
              "visualstudio2019-workload-vctools"
            )

& cmd /c "winrm set winrm/config/winrs @{MaxMemoryPerShellMB=`"2147483647`"}"

chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) {
    $measurement = Measure-Command {
        & chocolatey install --no-progress --limitoutput -y $p | Out-Default
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

[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, [System.EnvironmentVariableTarget]::User)

refreshenv