param (
   [string]$script
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
    if (!($stdout.EndOfStream -and $stderr.EndOfStream)) {
        while (!($stdout.EndOfStream -and $stderr.EndOfStream)) {
            $out_line = $stdout.ReadLine();
            $err_line = $stderr.ReadLine();
            if (![String]::IsNullOrEmpty($out_line)) {
                write-host $out_line
            }
            if (![String]::IsNullOrEmpty($err_line)) {
                Write-StdErr $err_line
            }
        }
    } else {
        Start-Sleep -Milliseconds 50
    }
}

$outpath = New-TemporaryFile
$errpath = New-TemporaryFile
$script = $env:USERPROFILE + "\" + $script

try {
    $sessioninfo = (query user vagrant | Select-String vagrant).toString().split() | where {$_}
    $psexec_session = $sessioninfo[2]
} catch {
    $psexec_session = -1
}

# quote parameters with whitespace again for cmd
$cmdargs = @()
ForEach ($arg in $args) {
    if ($arg -match "\s+") {
        $cmdargs += "`"$arg`""
    } else {
        $cmdargs += $arg
    }
}

$jobargs = @(
    "-nobanner"
)

if ($psexec_session -eq -1) {
    Write-Warning "User '$env:USERNAME' not logged in - running '$script' non-interactively"
} else {
    $admin_password = "vagrant"
    if (Test-Path env:ADMIN_PASSWORD) {
        $admin_password = $env:ADMIN_PASSWORD
    }
    $jobargs += @(
        "-i", $psexec_session,
        "-u", "vagrant", "-p", "$admin_password"
    )
}

$jobargs += @(
    "-w", "$env:USERPROFILE",
    "cmd.exe", "/C", "$script", "$cmdargs", "> $outpath", "2> $errpath"
)

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "psexec.exe"
$pinfo.CreateNoWindow = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments = $jobargs

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $pinfo

try {
    $process.Start() | Out-Null
} catch {
    Write-Error "Failure to start '$script' through psexec - aborting"
    exit $LASTEXITCODE
}

$stdout_file = [System.IO.File]::Open($outpath, 'Open', 'Read', 'ReadWrite')
$stdout = New-Object System.IO.StreamReader($stdout_file)
$stderr_file = [System.IO.File]::Open($errpath, 'Open', 'Read', 'ReadWrite')
$stderr = New-Object System.IO.StreamReader($stderr_file)

try {
    while (!$process.HasExited) {
        Repeat-Output $stdout $stderr
    }
    Repeat-Output $stdout $stderr
} catch {
    write-host "Some exception"
}

$stdout.Dispose();
$stdout_file.Close();
$stderr.Dispose();
$stderr_file.Close();

Remove-Item $outpath
Remove-Item $errpath

$process.WaitForExit()
if ($process.ExitCode -ne 0) {
    write-host "Process exited with" $process.ExitCode
}
exit $process.ExitCode
