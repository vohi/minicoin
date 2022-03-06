param (
    [string]$version = "10.2.0",
    [string]$package = "mingw"
)

. "c:\opt\minicoin\util\install_helper.ps1"

Install-Software $package $version
