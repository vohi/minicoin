if ( ! (Get-Service sshd)) {
    # Install the OpenSSH sever
    Add-WindowsCapability -Online -Name OpenSSH.Server
}

# Allow incoming connections to the SSH server
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

# Start sshd and ssh-agent automatically on startup
Set-Service sshd -StartupType Automatic
Set-Service ssh-agent -StartupType Automatic
Start-Service sshd
Start-Service ssh-agent

# put the public insecure vagrant key into C:\ProgramData\ssh\administrators_authorized_keys
icacls.exe "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
