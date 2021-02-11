$package = "PowerShell-7.1.1-win-x64.msi"

if (! (Test-Path "C:\Program Files\PowerShell\7")) {

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    (new-object net.webclient).DownloadFile(
        "https://github.com/PowerShell/PowerShell/releases/download/v7.1.1/${package}",
        "${package}")

    & .\${package} /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1
    Write-Host "Waiting for installation of PowerShell 7.1.1"

    while (! (Test-Path "C:\Program Files\PowerShell\7")) {
        Write-Host "."
        Start-Sleep -Seconds 5
    }

    Remove-Item "PowerShell-7.1.1-win-x64.msi"

}
