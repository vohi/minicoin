$packages = ("windows-sdk-10")

cd "$($env:SystemDrive)\ProgramData\Chocolatey\bin"

.\chocolatey feature enable -n=allowGlobalConfirmation

.\choco install --no-progress -y "VisualStudio2015Community" `
  -packageParameters "--AdminFile $($env:SystemDrive)\opt\minicoin\roles\msvc2015\AdminDeployment.xml"

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

Invoke-CmdScript "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\Tools\VsDevCmd.bat"
# Without this, rc is no longer available after installing Windows 10 SDK
[Environment]::SetEnvironmentVariable("Path", `
    "$($env:Path);$($env:WindowsSdkDir)bin\$($env:WindowsSDKVersion)x64", `
    [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, [System.EnvironmentVariableTarget]::User)
