param (
    [String]$user,
    [String]$role,
    [String]$role_path
)

choco install -y --no-progress ccache

for($i = 0; $i -lt $args.Length; $i++) {
    if ($($args[$i]).StartsWith("-")) {
        $setting = $($args[$i]).Trim("-")
        $value = "$($args[$i+1])"
        Write-Host "Setting $setting to $value"
        ccache --set-config=${setting}=${value}
    }
}
