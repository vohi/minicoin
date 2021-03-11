param (
    [string]$script,
    [string[]]$jobargs,
    [int]$repeat = 0,
    [switch]$privileged,
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

$admin_password = "vagrant"
if (Test-Path env:ADMIN_PASSWORD) {
    $admin_password = $env:ADMIN_PASSWORD
}

$psexec_args = @(
    "-nobanner", "-d"
)

try {
    Log-Verbose "Searching active session for user 'vagrant'"
    $ErrorActionPreference="SilentlyContinue"
    $sessioninfo = (query user vagrant | Select-String Active).toString().split() | where {$_}
    $ErrorActionPreference="Continue"
    if (($sessioninfo -eq $null) -or ($sessioninfo.Length -eq 0)) {
        throw "No session found"
    }
    $psexec_args += @(
        "-i", $sessioninfo[2],
        "-u", "vagrant", "-p", $admin_password
    )
    Log-Verbose "Active session found: $sessioninfo"
} catch {
    Write-StdErr "User '$env:USERNAME' not logged in - running '$script' non-interactively"
    $console = $true
}

if ($privileged) {
    $psexec_args += @("-h")
}
$psexec_args += @(
    "-w", "$env:USERPROFILE",
    "cmd.exe", "/C"
)

if ($script.ToLower().EndsWith("ps1")) {
    $psexec_args += @(
        "powershell.exe", "-ExecutionPolicy", "Bypass",
        "-File"
    )
}

$psexec_args += @(
    "$script", "$jobargs"
)

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
    if ($console) {
        Log-Verbose "Calling $script with Arguments: $jobargs"
        # minicoin process protocol
        Write-Host "minicoin.process.id=${PID}"
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

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "psexec.exe"
        $pinfo.CreateNoWindow = $true
        $pinfo.UseShellExecute = $false
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.Arguments = $psexec_args + @("> $outpath", "2> $errpath")

        Log-Verbose "Calling psexec.exe with arguments:"
        Log-Verbose "$psexec_args"

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo

        $process.Start() | Out-Null
        $process.WaitForExit()
        switch ($process.ExitCode) {
            {$_ -lt 7} { Write-StdErr "Failure to run '$psexec_args' through psexec - aborting"; exit 1 }
            default { $jobpid = $process.ExitCode } # feature of psexec
        }

        $process = Get-Process -Pid $jobpid
        if (! $process) {
            Write-StdErr "Failure to receive process started with psexec '$psexec_args' - aborting"
            exit 2
        }
        # minicoin process protocol
        Write-Host "minicoin.process.id=$jobpid"
        Write-Host "minicoin.process.sid=$($process.SessionId)"
        Log-Verbose "Reading $outpath and $errpath"
        $stdout_file = [System.IO.File]::Open($outpath, 'Open', 'Read', 'ReadWrite')
        $stdout = New-Object System.IO.StreamReader($stdout_file)
        $stderr_file = [System.IO.File]::Open($errpath, 'Open', 'Read', 'ReadWrite')
        $stderr = New-Object System.IO.StreamReader($stderr_file)
        Log-Verbose "Waiting for $($process | Out-String)"
        $handle = $process.Handle # cache so that we can get the exit code
        do {
            Repeat-Output $stdout $stderr
            Start-Sleep -Milliseconds 50
        } while (!$process.HasExited)
        $process.WaitForExit()
        # from now on, kill this process
        Write-Host "minicoin.process.id=${PID}"
        Repeat-Output $stdout $stderr
        $exit_code = $process.ExitCode

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
    if ($total -ge $repeat -and $repeat -gt 0) {
        break
    }
    if ($fswait) {
        $watchpath = $fsw.Path
        Write-Host "Waiting for file system changes in ${watchpath}"
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
