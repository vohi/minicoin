$packages = ( "winrar", "7zip", "firefox",
              "notepadplusplus", "cmake",
              "strawberryperl", "python2",
              "git", "llvm", "jom",
              "vscode")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\cinst -y $p }
.\chocolatey feature disable -n=allowGlobalConfirmation

