. "c:\opt\minicoin\util\install_helper.ps1"

$packages = ( "visualstudio2017buildtools",
              "visualstudio2017-workload-vctools")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }

.\chocolatey feature disable -n=allowGlobalConfirmation

write-host "Updating PATH"
refreshenv

Invoke-CmdScript "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, [System.EnvironmentVariableTarget]::User)
