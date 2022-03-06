function Run-KeepAlive {
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock,
        [int] $HeartBeat = 30,
        [Object[]] $Arguments
    )

    $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $Arguments
    [int] $waitCount = 0
    $startTime = $(get-date)
    while ($job.State -eq "Running") {
        $output = Receive-Job $job
        if ($output) {
            Write-Output $output
            $waitCount = 0
        } else {
            $waitCount += 1
            if ($waitCount -ge $HeartBeat) {
                $elapsedTime = new-timespan $startTime $(get-date)
                write-host "  $($elapsedTime.ToString("hh\:mm\:ss")) working..."
                $waitCount = 0
            }
            Wait-Job $job -Timeout 1
        }
    }
    Receive-Job $job
    Remove-Job $job
}

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

function Install-Software {
    param(
        [Parameter(Mandatory)][String] $package,
        [String] $version,
        [String] $command="chocolatey",
        [String[]] $arguments=@("install", "--no-progress", "--limitoutput", "-y"),
        [String] $versionSelect="--version"
    )

    write-host -NoNewline "Installing ${package}"
    $arguments += @($package)
    if ( $version -ne "" ) {
        write-host -NoNewline " version ${version}"
        $arguments+=@($versionSelect, $version)
    }
    write-host "."
    $measurement = Measure-Command {
        Run-KeepAlive -ScriptBlock {
            param($command, $arguments)
            & ${command} ${arguments} | Out-Default
        } -Arguments @($command, $arguments) -HeartBeat 30
    }
    $duration = ""
    if ($measurement.TotalMinutes -lt 1) {
        $duration = "$($measurement.TotalSeconds) Seconds"
    } else {
        $duration = $measurement.ToString("hh\:mm\:ss")
    }
    Write-Host "Installation of $package completed after $duration"
}
