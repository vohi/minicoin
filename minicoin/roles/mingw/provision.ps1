param (
    [string]$version = "11.2.0.07112021",
    [string]$package = "mingw"
)

. "c:\opt\minicoin\util\install_helper.ps1"

Install-Software $package $version

$path=[Environment]::GetEnvironmentVariable("PATH", 'machine')
[Environment]::SetEnvironmentVariable("PATH", "C:\ProgramData\chocolatey\lib\mingw\tools\install\mingw64\bin;${path}", 'machine')
refreshenv
