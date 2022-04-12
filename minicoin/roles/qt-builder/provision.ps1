param (
    [String]$Compilers = "msvc",
    [String]$Versions,
    [String]$Sqldrivers
)

. "c:\opt\minicoin\util\install_helper.ps1"

chocolatey feature enable -n=allowGlobalConfirmation

$index = 0
$Versions = @($Versions.split(","))
ForEach ($Compiler in $Compilers.split(",")) {
    $compilerVersion=$Versions[$index]
    if (@("mingw", "gcc").Contains($Compiler)) {
        if (!$compilerVersion) {
            $compilerVersion = "11.2.0.07112021"
        }

        Install-Software "mingw" $compilerVersion

        $path=[Environment]::GetEnvironmentVariable("PATH", 'machine')
        [Environment]::SetEnvironmentVariable("PATH", "C:\ProgramData\chocolatey\lib\mingw\tools\install\mingw64\bin;${path}", 'machine')
    } elseif (@("msvc").Contains($Compiler)) {
        if (!$compilerVersion) {
            $compilerVersion = "2022"
        }
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

        if (!$variables.ContainsKey("$compilerVersion")) {
            $keys = $variables.keys
            Write-Error "Version '${compilerVersion}' is not supported by this provisioning script, use one of: ${keys}"
            exit 1
        }

        $channelId=$variables[$compilerVersion].ChannelId
        $installDir=$variables[$compilerVersion].InstallDir
        $packages = $variables[$compilerVersion].Packages

        & cmd /c "winrm set winrm/config/winrs @{MaxMemoryPerShellMB=`"2147483647`"}"

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

        refreshenv

        Invoke-CmdScript "${InstallDir}\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

        [Environment]::SetEnvironmentVariable("PATH", $env:Path, 'user')
        [Environment]::SetEnvironmentVariable("INCLUDE", $env:INCLUDE, 'user')
        [Environment]::SetEnvironmentVariable("LIB", $env:LIB, 'user')
        [Environment]::SetEnvironmentVariable("VSINSTALLDIR", $installDir, 'user')
    } else {
        Write-Host "Unknown compiler '$Compiler'"
    }
    $index += 1
}

if ($Sqldrivers) {
    ForEach ($sqldriver in $Sqldrivers.Split(",")) {
        Write-Host "Installing client libraries for $sqldriver"
        switch -Exact ($sqldriver) {
            'psql' {
                $PostgreSQL_ROOT = "C:\ProgramData\pgsql"
                if (!(Test-Path $PostgreSQL_ROOT)) {
                    Run-KeepAlive -ScriptBlock {
                        param($PostgreSQL_ROOT)
                        $webclient = New-Object net.webclient # orders of magnitude faster than Invoke-WebRequest
                        $webclient.Downloadfile("https://get.enterprisedb.com/postgresql/postgresql-14.2-1-windows-x64-binaries.zip", "C:\Windows\Temp\psql.zip")
                        try {
                            Expand-Archive -Path "C:\Windows\Temp\psql.zip" -DestinationPath "C:\ProgramData"
                            [Environment]::SetEnvironmentVariable("PostgreSQL_ROOT", $PostgreSQL_ROOT, 'user')
                        }
                        catch {
                            Write-Error "Failed to extract archive"
                        }
                        finally {
                            Remove-Item -Force "C:\Windows\Temp\psql.zip"
                        }
                    } -Arguments $PostgreSQL_ROOT
                }
                Break;
            }
            'mysql' {
                $mysql_version = "mysql-connector-c++-8.0.28-win32"
                $MySQL_ROOT = "C:\ProgramData\${mysql_version}"
                if (!(Test-Path $MySQL_ROOT)) {
                    Run-KeepAlive -ScriptBlock {
                        param($MySQL_ROOT, $mysql_version)
                        $webclient = New-Object net.webclient # orders of magnitude faster than Invoke-WebRequest
                        $webclient.Downloadfile("https://cdn.mysql.com//Downloads/Connector-C++/${mysql_version}.zip", "C:\Windows\Temp\mysql.zip")
                        try {
                            Expand-Archive -Path 'C:\Windows\Temp\mysql.zip' -DestinationPath 'C:\ProgramData'
                            [Environment]::SetEnvironmentVariable("MySQL_ROOT", $MySQL_ROOT, 'user')
                        }
                        catch {
                            Write-Error "Failed to extract archive"
                        }
                        finally {
                            Remove-Item -Force "C:\Windows\Temp\mysql.zip"
                        }
                    } -Arguments @($MySQL_ROOT, $mysql_version)
                }
                Break;
            }
            'ibase' { # installing firebird SDK
                $IbaseSQL_ROOT = "C:\ProgramData\Firebird"
                if (!(Test-Path $IbaseSQL_ROOT)) {
                    Run-KeepAlive -ScriptBlock {
                        param ($IBaseSQL_ROOT)
                        $webclient = New-Object net.webclient # orders of magnitude faster than Invoke-WebRequest
                        $webclient.Downloadfile("https://github.com/FirebirdSQL/firebird/releases/download/v3.0.9/Firebird-3.0.9.33560-0_x64.zip", "C:\Windows\Temp\firebird.zip")
                        try {
                            Expand-Archive -Path "C:\Windows\Temp\firebird.zip" -DestinationPath $IBaseSQL_ROOT
                            [Environment]::SetEnvironmentVariable("IbaseSQL_ROOT", $IbaseSQL_ROOT, 'user')
                        }
                        catch {
                            Write-Error "Failed to extract archive"
                        }
                        finally {
                            Remove-Item -Force "C:\Windows\Temp\firebird.zip"
                        }
                    } -Arguments $IBaseSQL_ROOT
                }
                Break;
            }
            'odbc' {
                Write-Host "The ODBC SDK is already part of the Windows SDK."
            }
            Default {
                Write-Host "Don't know how to install SDK for SQL driver '$sqldriver' on Windows"
            }
        }
    }
}

chocolatey feature disable -n=allowGlobalConfirmation

refreshenv
