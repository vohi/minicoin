$packages = ( "visualstudio2017buildtools",
              "visualstudio2017-workload-vctools")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) { .\choco install --no-progress -y $p }

.\chocolatey feature disable -n=allowGlobalConfirmation

write-host "Updating PATH"
refreshenv

function Invoke-CmdScript {
    param(
      [String] $scriptName
    )
    $cmdLine = """$scriptName"" $args & set"
    & $Env:SystemRoot\system32\cmd.exe /c $cmdLine |
      Select-String '^([^=]*)=(.*)$' | ForEach-Object {
        $varName = $_.Matches[0].Groups[1].Value
        $varValue = $_.Matches[0].Groups[2].Value
        Set-Item env:$varName -Value $varValue
      }
  }

Invoke-CmdScript "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, [System.EnvironmentVariableTarget]::User)
