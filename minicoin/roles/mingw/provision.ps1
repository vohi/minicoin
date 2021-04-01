param (
    [string]$role,
    [string]$name,
    [string]$user,
    [string]$version = "8.1.0",
    [string]$package = "mingw"
)

write-host $role $name $user $package $version

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\choco install --no-progress -y $package --version $version
