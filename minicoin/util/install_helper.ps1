function Run-KeepAlive {
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock,
        [int] $HeartBeat = 30,
        [Object[]] $Arguments
    )

    $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $Arguments
    [int] $waitCount = 0
    while ($job.State -eq "Running") {
        $output = Receive-Job $job
        if ($output) {
            Write-Output $output
            $waitCount = 0
        } else {
            $waitCount += 1
            if ($waitCount -gt $HeartBeat) {
                write-host " working..."
                $waitCount = 0
            }
            Wait-Job $job -Timeout 1
        }
    }
    Receive-Job $job
    Remove-Job $job
}
