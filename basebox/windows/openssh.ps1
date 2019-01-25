# Install the OpenSSH sever
Add-WindowsCapability -Online -Name OpenSSH.Server

# Allow incoming connections to the SSH server
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

# Start sshd and ssh-agent automatically on startup
Set-Service sshd -StartupType Automatic
Set-Service ssh-agent -StartupType Automatic

