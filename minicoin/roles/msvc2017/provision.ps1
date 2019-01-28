$packages = ( "vscode",
              "visualstudio2017buildtools",
              "visualstudio2017-workload-vctools")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }

.\chocolatey feature disable -n=allowGlobalConfirmation

write-host "Copying helper scripts to Desktop!"
Copy-Item -Force -Recurse "$($env:SystemDrive)\vagrant\roles\msvc2017\env_helpers\" -Destination "$HOME\Desktop\"