
source "vagrant" "windows10-virtualbox" {
    communicator        = "ssh"
    source_path         = "tqtc/windows10"
    provider            = "virtualbox"
    template            = "Vagrantfile.template"
    box_name            = "tqtc/windows10"
}

source "vagrant" "windows10-vmware" {
    communicator        = "ssh"
    source_path         = "tqtc/windows10"
    provider            = "vmware_desktop"
    template            = "Vagrantfile.template"
    box_name            = "tqtc/windows10"
}

source "null" "testing" {
    communicator        = "ssh"
    ssh_host            = "127.0.0.1"
    ssh_port            = 2222
    ssh_username        = "vagrant"
    ssh_password        = "vagrant"
}

build {
    name = "manual"

    sources = [
        "vagrant.windows10-virtualbox", 
        "vagrant.windows10-vmware"
    ]

    provisioner "breakpoint" {
        disable = false
        note    = "Make manual changes, continue for packaging"
    }

    provisioner "powershell" {
        scripts = [
            "windows/cleanup.ps1"
        ]
    }
}

build {
    name = "upgrade"
    sources = [
        "vagrant.windows10-virtualbox",
        "vagrant.windows10-vmware"
    ]

    provisioner "file" {
        source = "/Users/vohi/Windows10Upgrade9252.exe"
        destination = "C:/Windows10Upgrade9252.exe"
    }

    provisioner "powershell" {
        scripts = [
            "windows/powershell.ps1"
        ]
    }

    # while the update installs
    # test that ssh access still works with 'vagrant ssh source'

    provisioner "breakpoint" {
        disable = false
        note    = "Run the upgrade assistant in 'C:\\Windows10Upgrade\\Windows10UpgraderApp.exe'!"
    }

    # Reboots
    # vagrant halt and up the source-machine
    # test that ssh access still works with 'vagrant ssh source'
    # if not, run the openssh.ps1 script manually

    provisioner "powershell" {
        scripts = [
            "windows/openssh.ps1",
            "windows/cleanup.ps1"
        ]
    }

    provisioner "windows-shell" {
        scripts = [
            "windows/winrm.cmd"
        ]
    }

    provisioner "breakpoint" {
        disable = false
        note    = "Run 'C:\\Users\\Public\\sdelete64 -z C:' before continuing!"
    }
}

build {
    name = "update"
    sources = [
        "vagrant.windows10-virtualbox",
        "vagrant.windows10-vmware",
        "null.testing"
    ]

    # VMware Tools upload
    provisioner "file" {
        only = [
            "vagrant.windows10-vmware"
        ]
        source = "/Applications/VMware Fusion.app/Contents/Library/isoimages/windows.iso"
        destination = "C:/Users/vagrant/vmware_tools.iso"
    }
    provisioner "powershell" {
        only = [
            "vagrant.windows10-vmware"
        ]
        script = "windows/vmware_tools.ps1"
    }

    # VirtualBox Guest Additions update
    provisioner "file" {
        only = [
            "vagrant.windows10-virtualbox"
        ]
        source = "/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso"
        destination = "C:/Users/vagrant/VBoxGuestAdditions.iso"
    }
    provisioner "powershell" {
        only = [
            "vagrant.windows10-virtualbox"
        ]
        scripts = [
            "windows/virtualbox_ga.ps1",
        ]
    }

    provisioner "powershell" {
        scripts = [
            "windows/provision.ps1",
            "windows/stripdown.ps1",
            "windows/openssh.ps1",
            "windows/softwareupdate.ps1",
            "windows/cleanup.ps1"
        ]
    }

    provisioner "windows-restart" {
    }

    provisioner "breakpoint" {
        disable = false
        note    = "Run 'C:\\Users\\Public\\sdelete64 -z C:' before continuing!"
    }
}
