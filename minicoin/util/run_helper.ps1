param (
    [string]$script,
    [int]$repeat,
    [switch]$privileged,
    [switch]$verbose,
    [switch]$console
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

function Repeat-Output {
    param (
        [System.Object]$stdout,
        [System.Object]$stderr
    )
    while (!($stdout.EndOfStream -and $stderr.EndOfStream)) {
        $out_line = $stdout.ReadLine();
        $err_line = $stderr.ReadLine();
        if (![String]::IsNullOrEmpty($out_line)) {
            write-host $out_line
        }
        if (![String]::IsNullOrEmpty($err_line)) {
            Write-StdErr $err_line
        }
        Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 250
}

Set-Location $env:USERPROFILE
$script = $env:USERPROFILE + "\" + $script

# quote parameters with whitespace again for cmd
$cmdargs = @()
ForEach ($arg in $args) {
    if ($arg -match "\s+") {
        $cmdargs += "`"$arg`""
    } else {
        $cmdargs += $arg
    }
    if ($arg -eq "--privileged") {
        $privileged = $True
    }
}

$admin_password = "vagrant"
if (Test-Path env:ADMIN_PASSWORD) {
    $admin_password = $env:ADMIN_PASSWORD
}

$jobargs = @(
    "-nobanner"
)

try {
    if ($verbose) {
        Write-StdErr "Searching active session for user 'vagrant'"
    }
    $ErrorActionPreference="SilentlyContinue"
    $sessioninfo = (query user vagrant | Select-String Active).toString().split() | where {$_}
    $ErrorActionPreference="Continue"
    if (($sessioninfo -eq $null) -or ($sessioninfo.Length -eq 0)) {
        throw "No session found"
    }
    $jobargs += @(
        "-i", $sessioninfo[2],
        "-u", "vagrant", "-p", $admin_password
    )
    if ($verbose) {
        Write-StdErr "Active session found: $sessioninfo"
    }
} catch {
    Write-StdErr "User '$env:USERNAME' not logged in - running '$script' non-interactively"
}

if ($privileged) {
    $jobargs += @("-h")
}
$jobargs += @(
    "-w", "$env:USERPROFILE",
    "cmd.exe", "/C"
)

if ($script.ToLower().EndsWith("ps1")) {
    $jobargs += @(
        "powershell.exe", "-ExecutionPolicy", "Bypass",
        "-File"
    )
}

$jobargs += @(
    "$script", "$cmdargs"
)

$success_count = 0
$exit_code = 0
for ($i = 0; $i -lt $repeat; $i++) {
    try {
        if ($console) {
            if ($verbose) {
                Write-StdErr "Calling $script with Arguments: $cmdargs"
            }
            if ($script.ToLower().EndsWith("ps1")) {
                $ErrorActionPreference="SilentlyContinue"
                & $script $cmdargs 2>&1
                $ErrorActionPreference="Continue"
            } else {
                & $script $cmdargs
            }
            $exit_code = $LASTEXITCODE
        } else {
            $outpath = New-TemporaryFile
            $errpath = New-TemporaryFile

            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "psexec.exe"
            $pinfo.CreateNoWindow = $true
            $pinfo.UseShellExecute = $true
            $pinfo.Arguments = $jobargs + @("> $outpath", "2> $errpath")

            if ($verbose) {
                Write-StdErr "Calling $($pinfo.FileName) with Arguments:"
                Write-StdErr "$jobargs"
            }

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $pinfo

            $process.Start() | Out-Null
            if ($verbose) {
                Write-StdErr "Process started with id $($process.id)"
            }
        }
    } catch {
        Write-StdErr "Failure to start '$script' through psexec - aborting"
        Write-StdErr "Error message: $($_.ToString())"
        $PSItem.InvocationInfo | Format-List *
        exit $LASTEXITCODE
    }

    if (!$console) {
        if ($verbose) {
            Write-StdErr "Reading $outpath and $errpath"
        }

        $stdout_file = [System.IO.File]::Open($outpath, 'Open', 'Read', 'ReadWrite')
        $stdout = New-Object System.IO.StreamReader($stdout_file)
        $stderr_file = [System.IO.File]::Open($errpath, 'Open', 'Read', 'ReadWrite')
        $stderr = New-Object System.IO.StreamReader($stderr_file)

        try {
            if ($verbose) {
                Write-StdErr "Waiting for $process"
            }
            while (!$process.HasExited) {
                Repeat-Output $stdout $stderr
            }
            Repeat-Output $stdout $stderr
        } catch {
            Write-StdErr "Exception while reading process output - exiting"
            Write-StdErr "Error message: $($_.ToString())"
            $PSItem.InvocationInfo | Format-List *
        }

        if ($verbose) {
            Write-StdErr "Cleaning up $outpath and $errpath"
        }

        $stdout.Dispose();
        $stdout_file.Close();
        $stderr.Dispose();
        $stderr_file.Close();

        try {
            Remove-Item $outpath | Out-Null
            Remove-Item $errpath | Out-Null
        } catch {
            Write-StdErr "Error removing temporary files"
        }

        $process.WaitForExit()
        $exit_code = $process.ExitCode
    }
    if ($exit_code -ne 0) {
        Write-StdErr "Process exited with $exit_code"
    } else {
        $success_count++
    }

    if ($repeat -gt 1) {
        if ($exit_code -ne 0) {
            $printer="Write-StdErr"
        } else {
            $printer="Write-Output"
        }
        Invoke-Expression -Command "$printer 'Run $($i + 1)/${repeat}: Exit code ${exit_code}'"
    }
}

if ($repeat -gt 1) {
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
