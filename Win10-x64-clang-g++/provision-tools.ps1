$packages = ( "winrar", "7zip", "firefox",
              "notepadplusplus", "cmake",
              "strawberryperl", "python2",
              "git", "llvm",
              "vscode")

### FIXME: add "jom", it doesn't seem to work out of the box

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\cinst -y $p }
.\chocolatey feature disable -n=allowGlobalConfirmation

