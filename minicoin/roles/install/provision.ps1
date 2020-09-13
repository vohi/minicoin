param (
    [String[]]$Packages
)

$Packages = $Packages.split(",")

chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) {
    $measurement = Measure-Command {
        & chocolatey install --no-progress --limitoutput -y $p | Out-Default
    }
    
    if ($measurement.TotalMinutes -lt 1) {
        $duration = "$($measurement.TotalSeconds) Seconds"
    } else {
        $duration = $measurement.ToString("hh\:mm\:ss")
    }
    Write-Host "Installation of $p completed after $duration"
}
chocolatey feature disable -n=allowGlobalConfirmation
