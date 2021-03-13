param (
    [string]$jobid,
    [string]$script,
    [string[]]$jobargs,
    [int]$repeat = 0,
    [switch]$verbose,
    [switch]$console,
    [switch]$fswait
)

function Write-StdErr {
    param ([PSObject] $InputObject)
    $outFunc = if ($host.Name -eq 'ConsoleHost') {
        [Console]::Error.WriteLine
    } else {
        $host.ui.WriteErrorLine
    }
    if ($InputObject) {
        [void] $outFunc.Invoke($InputObject.ToString())
    } else {
        [string[]] $line = @()
        $Input | % { $lines += $_.ToString() }
        [void] $outFunc.Invoke($lines -join "`r`n")
    }
}

function Log-Verbose {
    param ([PSObject] $InputObject)
    if ($verbose) {
        Write-StdErr $InputObject.ToString()
    }
}

function Repeat-Output {
    param (
        [System.Object]$stdout,
        [System.Object]$stderr
    )
    while (!($stdout.EndOfStream -and $stderr.EndOfStream)) {
        $out_line = $stdout.ReadLine();
        $err_line = $stderr.ReadLine();
        $havedata = $false
        if (![String]::IsNullOrEmpty($out_line)) {
            write-host $out_line
            $havedata = $true
        }
        if (![String]::IsNullOrEmpty($err_line)) {
            Write-StdErr $err_line
            $havedata = $true
        }
        if (!$havedata) {
            Start-Sleep -Milliseconds 25
        }
    }
}

Set-Location $env:USERPROFILE
$script = $env:USERPROFILE + "\" + $script

try {
    Log-Verbose "Searching active session for user 'vagrant'"
    $ErrorActionPreference="SilentlyContinue"
    $sessioninfo = (query user vagrant | Select-String Active).toString().split() | where {$_}
    $ErrorActionPreference="Continue"
    if (($sessioninfo -eq $null) -or ($sessioninfo.Length -eq 0)) {
        throw "No session found"
    }
    Log-Verbose "Active session found: $sessioninfo"
} catch {
    Write-StdErr "User '$env:USERNAME' not logged in - running '$script' non-interactively"
    $console = $true
}

if ($fswait) {
    $watchpath = $jobargs[0]
    Log-Verbose "Watching ${watchpath}"
    $fsw = New-Object System.IO.FileSystemWatcher
    $fsw.Path = $watchpath
    $fsw.IncludeSubdirectories = $true
}

$success_count = 0
$exit_code = 0
$total = 0
do {
    if (!$(Test-Path $script)) {
        Log-Verbose "Script is gone, aborting"
        exit 130 # interrupt exit code
    }
    # minicoin process protocol - interrupts kill this process
    Write-Host "minicoin.process.id=${PID}"
    if ($console) {
        Log-Verbose "Calling $script with Arguments: $jobargs"
        if ($script.ToLower().EndsWith("ps1")) {
            $ErrorActionPreference="SilentlyContinue"
            & $script $jobargs 2>&1
            $ErrorActionPreference="Continue"
        } else {
            & $script $jobargs
        }
        $exit_code = $LASTEXITCODE
    } else {
        $outpath = New-TemporaryFile
        $errpath = New-TemporaryFile
        $taskpath = "\minicoin-jobs\"
        $taskcommand = "cmd.exe"

        $taskargs = @("/C")
        if ($script.ToLower().EndsWith("ps1")) {
            $taskargs += @("powershell.exe", "-ExecutionPolicy", "Bypass", "-File")
        }
        $taskargs += @($script)
        $taskargs += $jobargs
        $taskargs += @("> ${outpath} 2> ${errpath}")

        Log-Verbose "Running 'cmd.exe $taskargs'"
        $taskAction = New-ScheduledTaskAction -Execute $taskcommand -Argument [string]$taskargs -WorkingDirectory $ENV:USERPROFILE
        $task = Register-ScheduledTask -TaskPath $taskpath -Action $taskAction -TaskName $jobid -RunLevel Highest

        if (!$task) {
            Write-Error "Failed to register task, aborting"
            exit 1
        }
        Log-Verbose "Registered task ${task}"
        Start-ScheduledTask -InputObject $task
        # from now on, interrupts stop the task
        Write-Host "minicoin.process.id="

        Log-Verbose $((Get-ScheduledTaskInfo -TaskPath $taskpath -TaskName $jobid).LastTaskResult)
        Log-Verbose "Reading $outpath and $errpath"
        $stdout_file = [System.IO.File]::Open($outpath, 'Open', 'Read', 'ReadWrite')
        $stdout = New-Object System.IO.StreamReader($stdout_file)
        $stderr_file = [System.IO.File]::Open($errpath, 'Open', 'Read', 'ReadWrite')
        $stderr = New-Object System.IO.StreamReader($stderr_file)

        $taskstate = 0
        do {
            Repeat-Output $stdout $stderr
            Start-Sleep -Milliseconds 50
            $task = Get-ScheduledTask -TaskPath $taskpath -TaskName $jobid
            $taskstate = $task.State
        } while ($taskstate -eq 'Running')
        # task finished, let interrupts kill this process again
        Write-Host "minicoin.process.id=${PID}"
        $taskinfo = Get-ScheduledTaskInfo -TaskPath $taskpath -TaskName $jobid
        $exit_code = $taskinfo.LastTaskResult

        Unregister-ScheduledTask -TaskPath $taskpath -TaskName $jobid -Confirm:$false
        Repeat-Output $stdout $stderr

        Log-Verbose "Cleaning up $outpath and $errpath"

        $stdout.Dispose();
        $stdout_file.Close();
        $stderr.Dispose();
        $stderr_file.Close();

        try {
            $ErrorActionPreference="SilentlyContinue"
            Remove-Item $outpath | Out-Null
            Remove-Item $errpath | Out-Null
            $ErrorActionPreference="Continue"
        } catch {
            Write-StdErr "Error removing temporary files"
        }
    }
    if ($exit_code -ne 0) {
        Log-Verbose "Process exited with $exit_code"
        if ($exit_code -eq 71) {
            Write-StdErr "System doesn't accept any new tasks, this should resolve itself in a few minutes!"
        }
    } else {
        $success_count++
    }

    $total += 1
    if ($repeat -ne 1) {
        if ($exit_code -ne 0) {
            $printer="Write-StdErr"
        } else {
            $printer="Write-Output"
        }
        Invoke-Expression -Command "$printer 'Run ${total}/${repeat}: Exit code ${exit_code}'"
    }
    if ($exit_code -eq 0x00041306) { # error code for "the last run of the task was terminated by the user"
        Log-Verbose "The task was terminated by the user"
        $exit_code = 130
        break
    }

    if ($total -ge $repeat -and $repeat -gt 0) {
        break
    }
    if ($fswait) {
        $watchpath = $fsw.Path
        $time = Get-Date -Format "HH:mm:ss"
        Write-Host "(${time}) Waiting for file system changes in ${watchpath}"
        $fsw.WaitForChanged(15) | Out-Null
    }
} while ($true)

if ($repeat -ne 1) {
    if ($success_count -lt $repeat) {
        $printer="Write-StdErr"
    } else {
        $printer="Write-Output"
    }
    Invoke-Expression -Command "$printer 'Success rate is ${success_count}/${repeat}'"
    exit $repeat - $success_count
} else {
    exit $exit_code
}
