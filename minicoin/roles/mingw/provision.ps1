param (
    [string]$version = "10.2.0",
    [string]$package = "mingw"
)

write-host "Installing ${package} version ${version}"

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\choco install --no-progress -y $package --version $version
