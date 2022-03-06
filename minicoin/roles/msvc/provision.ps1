param (
    [String]$Version = "2022"
)

$variables = @{
    "2017" = @{
        Packages=("visualstudio2017buildtools", "visualstudio2017-workload-vctools")
        ChannelId="VisualStudio.15.Release"
        InstallDir="C:\Program Files (x86)\Microsoft Visual Studio\2017"
    }
    "2019" = @{
        Packages=("visualstudio2019-workload-vctools")
        ChannelId="VisualStudio.16.Release"
        InstallDir="C:\Program Files (x86)\Microsoft Visual Studio\2019"
    }
    "2022" = @{
        Packages=("visualstudio2022-workload-vctools")
        ChannelId="VisualStudio.17.Release"
        InstallDir="C:\Program Files (x86)\Microsoft Visual Studio\2022"
    }
}

if (!$variables.ContainsKey("$Version")) {
    $keys = $variables.keys
    Write-Error "Version '${Version}' is not supported by this provisioning script, use one of: ${keys}"
    exit 1
}

$channelId=$variables[$Version].ChannelId
$installDir=$variables[$Version].InstallDir
$packages = $variables[$Version].Packages

. "c:\opt\minicoin\util\install_helper.ps1"


& cmd /c "winrm set winrm/config/winrs @{MaxMemoryPerShellMB=`"2147483647`"}"

chocolatey feature enable -n=allowGlobalConfirmation
ForEach ( $p in $packages ) {
    Install-Software $p
}

$vc_workloads = (
    "Microsoft.VisualStudio.Component.VC.ATL",
    "Microsoft.VisualStudio.Component.VC.ATLMFC"
)

ForEach ( $p in $vc_workloads ) {
    Install-Software -package $p -command "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" `
        -arguments @(
            "modify", "--norestart", "--quiet",
            "--productId", "Microsoft.VisualStudio.Product.BuildTools",
            "--channelId", "$channelId", "--add"
        )
}

chocolatey feature disable -n=allowGlobalConfirmation

refreshenv

Invoke-CmdScript "${InstallDir}\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

[Environment]::SetEnvironmentVariable("PATH", $env:Path, 'user')
[Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, 'user')
[Environment]::SetEnvironmentVariable("LIB", $env:LIB, 'user')
[Environment]::SetEnvironmentVariable("VSINSTALLDIR", $installDir, 'user')

refreshenv
