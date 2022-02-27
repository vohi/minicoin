param(
    [string]$reverse,
    [string]$role,
    [string]$boxname,
    [string]$user,
    [string]$mutagen_host_ip,
    [string[]]$alpha,
    [string[]]$beta
)

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

    Write-Host "Starting mutagen daemon"
    c:\mutagen\mutagen daemon register
    c:\mutagen\mutagen daemon start
}

function Mount-Paths {
    param(
        [string[]]$Alphas,
        [string[]]$Betas
    )
    begin {
        if ($Alphas.count -ne $Betas.count) {
            throw "Alphas and Betas need to have the same number of entries!"
        }
        if ($reverse -eq "true") {
            ssh-keyscan $mutagen_host_ip >> c:\Users\vagrant\.ssh\known_hosts
        }
    }
    process{
        if ($reverse -eq "true") {
            c:\mutagen\mutagen sync terminate minicoin | Out-Null
        }
        for ($i = 0; $i -lt $Alphas.count; $i++) {
            $a = $Alphas[$i]
            $b = $Betas[$i]
            if (!(Test-Path $b)) {
                New-Item -ItemType Directory -Force -Path $b | Out-Null
            }
            if ($reverse -eq "true") {
                Write-Host "Mapping as" $user "from" $a "on" $mutagen_host_ip "to" $b
                echo yes | c:\mutagen\mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin ${user}@${mutagen_host_ip}:$a $b
            }
        }
    }
    end {
        if ($reverse -eq "true") {
            Write-Host "Established mutagen sync points:"
            c:\mutagen\mutagen sync list
        }
    }
}

if ($reverse -eq "true") {
    Install-Mutagen -InstallPath "$env:SystemDrive\mutagen" -Version "0.13.1"
}
Mount-Paths -Alphas $alpha.split(",") -Betas $beta.split(",")
