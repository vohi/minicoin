param (
    [String]$template,
    [String[]]$runlist = @(),
    [String[]]$skiplist = @(
        "disable-netadapterlso",
        "allow-remote-desktop-access",
        "change-resolution",
        "set-proxy",
        "enable-guest-logon",
        "python-32bit",
        "install_telegraf",
        "install-mcuxpresso",
        "install-virtualbox",
        "openssl_for_android",
        "qnx_700",
        "android",
        "emsdk",
        "squish", "squish-coco"
        )
)

. "c:\minicoin\util\install_helper.ps1"

if ( $runlist.Length -eq 1 ) {
    $runlist = $runlist[0].Split(",")
}
if ( $skiplist.Length -eq 1 ) {
    $skiplist = $skiplist.Split(",")
}

# provisioning scripts run as Administrator, so $PWD is C:\Windows\system32
Set-Location -Path $env:USERPROFILE

if ( Test-Path C:\minicoin\roles\coin-node\.hosts -PathType Leaf ) {
    Write-Output "Adding hosts"
    Get-Content c:\minicoin\roles\coin-node\.hosts | Add-Content -Path C:\Windows\system32\drivers\etc\hosts
}

try {
    cd Documents\coin\provisioning
}
catch {
    Write-Error "Can't find coin scripts"
    exit 1
}

try {
    cd $template
}
catch {
    Write-Error "Can't find template '$template'"
    exit 2
}

ForEach ( $script in Get-ChildItem -Path .\* -Include *.ps1 | Sort-Object -Property Name ) {
    [string]$scriptfile = Split-Path $script -leaf
    [string]$scriptname = $scriptfile.SubString(3, $scriptfile.Length-7)
    if ( $skiplist.Contains($scriptname) -and ( -not $runlist.Contains($scriptname) ) ) {
        Write-Output "-- Skipping '$scriptfile'"
    } else {
        Write-Output "++ Executing '$scriptfile'"
        try {
            & $script | Out-Default
            Write-Output "   Success"
        }
        catch {
            [Console]::Error.WriteLine("   FAIL")
            $_
        }
    }
    Start-Sleep -Seconds 1 # better ordering of stdout and stderr
}
