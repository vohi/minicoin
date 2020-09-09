$packages = ( "visualstudio2019buildtools",
              "visualstudio2019-workload-vctools")

winrm set winrm/config/winrs @{MaxMemoryPerShellMB="2147483647"}

chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) {
  choco install -y --timeout 300 --no-progress $p
}

chocolatey feature disable -n=allowGlobalConfirmation

write-host "Updating Environment"
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

Invoke-CmdScript "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, [System.EnvironmentVariableTarget]::User)

refreshenv