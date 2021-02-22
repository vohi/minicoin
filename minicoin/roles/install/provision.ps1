param (
    [String[]]$Packages,
    [String[]]$Options = @("--no-progress","--limitoutput","-y")
)

$Packages = $Packages.split(",")

chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) {
    $measurement = Measure-Command {
        & chocolatey install $Options $p | Out-Default
        if ( -not $? )
        {
            Write-Error "Installation of $p failed"
            exit 1
        }
    }
    
    if ($measurement.TotalMinutes -lt 1) {
        $duration = "$($measurement.TotalSeconds) Seconds"
    } else {
        $duration = $measurement.ToString("hh\:mm\:ss")
    }
    Write-Host "Installation of $p completed after $duration"
}
chocolatey feature disable -n=allowGlobalConfirmation
