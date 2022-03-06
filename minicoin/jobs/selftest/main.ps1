param (
    [string]$jobdir,
    [string]$hostdir,
    [string[]]$array
)
$ExitCode = 0

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
# $ErrorActionPreference="SilentlyContinue"
write-host "Hello runner!"
write-host "Arguments received:"
write-host "- $jobdir (jobdir)"
write-host "- $hostdir (hostdir)"
write-host "- $array (array $($array.Count))"
foreach ($arg in $Args) {
    write-host "- ${arg} $($arg.Count)"
    if ($arg -eq "error") {
        $ExitCode=42
    }
}

foreach ($i in 1..5) {
    write-host "Testing stdout $i"
    write-stderr "Testing stderr $i"
    write-error "Testing write-error $i"
    Start-Sleep 1
}

if ($ExitCode -gt 0) {
    write-stderr "Error $ExitCode occurred"
}

exit $ExitCode
