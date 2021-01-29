param (
    [string]$shell,
    [string]$workflow
)

$scriptdir = $PSScriptRoot
$shellcmd = $shell

$shellcmd = $shellcmd -replace [RegEx]::Escape("{0}"), "$scriptdir\$workflow"
$shellcmd = $shellcmd -Split " "

$shell = $shellcmd[0]
$shellargs = $shellcmd[1..$shellcmd.Length]
$shell = $shell -replace "bash", "c:\program files\git\usr\bin\bash.exe"

$hosthome = $args[0]
$jobdir = $args[1]
$jobdir = $jobdir -replace $hosthome, $env:USERPROFILE
$jobdir = $jobdir -replace "/", "\"

cd C:\Users\vagrant
New-Item -ItemType SymbolicLink -Path "source" -Target $jobdir

Write-Host "Working directory: $jobdir"

$env:PATH = "`"C:\program files\git\usr\bin`";$env:PATH"

& $shell $shellargs
