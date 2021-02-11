winrm quickconfig -q
winrm set winrm/config/winrs @{MaxMemoryPerShellMB="2147483647"}
winrm set winrm/config @{MaxTimeoutms="1800000"}
winrm set winrm/config/service @{AllowUnencrypted="true"}
winrm set winrm/config/service/auth @{Basic="true"}
sc config WinRM start=auto
