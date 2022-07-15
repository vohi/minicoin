param (
    [string]$admin_password
)

if ($admin_password) {
    [Environment]::SetEnvironmentVariable("ADMIN_PASSWORD", "$admin_password", [System.EnvironmentVariableTarget]::Machine)
}

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
    choco install --no-progress --confirm --limitoutput -params "/SSHServerFeature /AlsoLogToFile" openssh
    if (!(Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server')) {
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }
    Set-Service sshd -StartupType Automatic
    Set-Service ssh-agent -StartupType Automatic
}

choco install --no-progress --confirm --limitoutput pstools
psexec -nobanner -accepteula | Out-Null

chocolatey feature disable -n=allowGlobalConfirmation

# set PowerShell as the default log-in shell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\cmd.exe" -PropertyType String -Force

# fix file permissions for administrators_authorized_keys
$file = "$Env:programdata\ssh\administrators_authorized_keys"
$public_key = "$Env:systemroot\temp\id_rsa.pub"
if (Test-Path $public_key) {
    Get-Content -Path $public_key | Add-Content -Path $file
}
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

# remove ourselves so that future provisionings can overwrite
Remove-Item -Path $PSScriptRoot -Force -Recurse
exit 0
