param (
    [Parameter(Mandatory=$true,Position=1)][string]$jobdir,
    [Parameter(Mandatory=$true,Position=2)][string]$hostdir,
    [Parameter(Mandatory=$false)][string]$exe = ".*",
    [Parameter(Mandatory=$false)][string]$bindir,
    [Parameter(ValueFromRemainingArguments=$true)]$args
)

$projectname = (Get-Item -Path $jobdir).Basename
if (! $builddir) {
    $bindir = "${projectname}-build"
}

if ($(Test-Path -Path $bindir)) {
    cd $bindir
}

[array]$exefiles = @(Get-ChildItem . -recurse | where { $_.extension -eq ".exe" -and $_.basename -match "^${exe}$" })

if ( $exefiles.Count -gt 1) {
    $filtered = $exefiles | where { $_.basename -match $projectname }
    if ($filtered) {
        $exefiles = $filtered
    }
}

if ( $exefiles.Count -lt 1) {
    Write-Error "No matching executable found in $(Get-Location)"
    exit 2
}

if ( $exefiles.Count -gt 1) {
    Write-Error "Multiple executables found, specify via --exe!"
    $exefiles | foreach { Write-Error $_.FullName }
    exit 2
}
$exefile = $exefiles[0]

& cmd /C "qt-cmake > NUL 2> NUL & $($exefile.FullName) ${args}"
exit $LASTEXITCODE
