$packages = ( "vscode",
              "visualstudio2017buildtools",
              "visualstudio2017-workload-vctools")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }

.\chocolatey feature disable -n=allowGlobalConfirmation

write-host "Copying helper scripts to Desktop!"
Copy-Item -Force -Recurse "$($env:SystemDrive)\vagrant\roles\msvc2017\env_helpers\" -Destination "$HOME\Desktop\"

write-host "Updating PATH"

function Invoke-CmdScript {
    param(
      [String] $scriptName
    )
    $cmdLine = """$scriptName"" $args & set"
    & $Env:SystemRoot\system32\cmd.exe /c $cmdLine |
      Select-String '^([^=]*)=(.*)$' | ForEach-Object {
        $varName = $_.Matches[0].Groups[1].Value
        $varValue = $_.Matches[0].Groups[2].Value
        [Environment]::SetEnvironmentVariable($varName, $varValue,
        [System.EnvironmentVariableTarget]::User)
      }
  }

Invoke-CmdScript "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\VC\\Auxiliary\\Build\\vcvarsall.bat" amd64
