$version = "7.2.1"
$package = "PowerShell-${version}-win-x64.msi"

if (! (Test-Path "C:\Program Files\PowerShell\7")) {

    curl -o ${package} "https://github.com/PowerShell/PowerShell/releases/download/v${version}/${package}"

    & .\${package} /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1
    Write-Host "Waiting for installation of PowerShell ${version}"

    while (! (Test-Path "C:\Program Files\PowerShell\7")) {
        Write-Host "."
        Start-Sleep -Seconds 5
    }

    Remove-Item $package
}
