if (!($env:ChocolateyInstall)) {
    write-host "Install Chocolatey . . . "
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | out-null
} else {
    write-host "Upgrade Chocolatey . . . "
    cd $env:ChocolateyInstall\bin
    choco upgrade chocolatey
}

cd $env:ChocolateyInstall\bin
chocolatey feature enable -n=allowGlobalConfirmation

if (!(Get-WmiObject win32_service -Filter "Name = 'sshd'")) {
    write-host "Installing OpenSSH server"
    choco install --no-progress -y -params "/SSHServerFeature /AlsoLogToFile" openssh
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    Set-Service sshd -StartupType Automatic
    Set-Service ssh-agent -StartupType Automatic
}

choco install -y -no-progress "pstools"
psexec -nobanner -accepteula | Out-Null

chocolatey feature disable -n=allowGlobalConfirmation

# set PowerShell as the default log-in shell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force

# fix file permissions for administrators_authorized_keys
$file = "$Env:programdata\ssh\administrators_authorized_keys"
$acl = Get-Acl $file
$acl.SetAccessRuleProtection($true,$false)
$userid = New-Object System.Security.Principal.Ntaccount("NT AUTHORITY\Authenticated Users")
$acl.PurgeAccessRules($userid)
$userid = New-Object System.Security.Principal.Ntaccount("NT AUTHORITY\LOCAL SERVICE")
$acl.PurgeAccessRules($userid)
$accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule("vagrant","FullControl","Allow")
$acl.SetAccessRule($accessrule)
$accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")
$acl.SetAccessRule($accessrule)
$acl | Set-Acl $file

function Download-Mutagen {
    param(
        $ARCH,
        $VERSION,
        $PATH
    )
    $PLATFORM="windows"
    $FILE="mutagen_${PLATFORM}_${ARCH}_v${VERSION}.tar.gz"
    $URL="https://github.com/mutagen-io/mutagen/releases/download/v${VERSION}/${FILE}"

    Write-Host "Downloading '$URL'"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $webClient = new-object net.webclient
    $webClient.DownloadFile($URL, $PATH) | out-null
}

function Install-Mutagen {
    param(
        [string]$Version,
        [string]$InstallPath
    )

    if (!(Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    }
    cd $InstallPath
    if (!(Test-Path "mutagen.tar.gz")) {
        Download-Mutagen -Arch amd64 -Version $Version -Path "${InstallPath}\mutagen.tar.gz"
    }
    tar -xzf mutagen.tar.gz
    Remove-Item mutagen.tar.gz

    tar -xzf "${InstallPath}\mutagen-agents.tar.gz" windows_amd64
    move windows_amd64 mutagen-agent.exe
    ./mutagen-agent.exe install
}

Install-Mutagen -InstallPath "$env:SystemDrive\mutagen" -Version "0.11.7"

