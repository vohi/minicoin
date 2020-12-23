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

$error_count = 0

ForEach ( $script in Get-ChildItem -Path .\* -Include *.ps1 | Sort-Object -Property Name ) {
    [string]$scriptfile = Split-Path $script -leaf
    [string]$scriptindex = $scriptfile.SubString(0, 2)
    [string]$scriptname = $scriptfile.SubString(3, $scriptfile.Length-7)
    if ( $skiplist.Contains($scriptname) -and ( -not $runlist.Contains($scriptname) ) ) {
        Write-Output "-- Skipping '$scriptfile'"
    } else {
        Write-Output "++ Executing '$scriptfile'"

        $output = [System.Collections.ArrayList]@()
        try {
            $out = & $script 6>&1 | ForEach-Object {
                if ( $scriptfile -eq "99-version.ps1" ) {
                    Write-Output $_
                }
                $output.Add($_)
            }
            Write-Output "   Success"
        }
        catch {
            $error_count++
            ForEach ($outline in $output) {
                Write-Output "   ${scriptindex}: $outline"
            }
            [Console]::Error.WriteLine(" - ${scriptindex}: FAIL ($scriptfile)")
            [Console]::Error.WriteLine(" - ${scriptindex}: $_")
            Start-Sleep -Seconds 1 # let stream sync catch up
        }
    }
}

exit $error_count
