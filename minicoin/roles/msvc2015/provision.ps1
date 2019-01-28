# $packages = ("")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation

# ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }

.\choco install -y "VisualStudio2015Community" -packageParameters "--AdminFile $($env:SystemDrive)\vagrant\roles\msvc2015\AdminDeployment.xml"

.\chocolatey feature disable -n=allowGlobalConfirmation

write-host "Copying helper scripts to Desktop!"
Copy-Item -Force -Recurse "$($env:SystemDrive)\vagrant\roles\msvc2015\env_helpers\" -Destination "$HOME\Desktop\"