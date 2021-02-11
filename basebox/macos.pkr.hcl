source "vagrant" "macos1015-virtualbox" {
    communicator        = "ssh"
    source_path         = "tqtc/macos1015"
    provider            = "virtualbox"
    template            = "Vagrantfile.template"
    box_name            = "tqtc/macos1015"
}

source "vagrant" "macos11-virtualbox" {
    communicator        = "ssh"
    source_path         = "tqtc/macos11"
    provider            = "virtualbox"
    template            = "Vagrantfile.template"
    box_name            = "tqtc/macos11"
}

source "vagrant" "macos1015-vmware" {
    communicator        = "ssh"
    source_path         = "tqtc/macos1015"
    provider            = "vmware_desktop"
    template            = "Vagrantfile.template"
    box_name            = "tqtc/macos1015"
}

source "vagrant" "macos11-vmware" {
    communicator        = "ssh"
    source_path         = "tqtc/macos11"
    provider            = "vmware_desktop"
    template            = "Vagrantfile.template"
    box_name            = "tqtc/macos11"
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
        "vagrant.macos1015-virtualbox", 
        "vagrant.macos11-virtualbox",
        "vagrant.macos1015-vmware",
        "vagrant.macos11-vmware"
    ]

    provisioner "breakpoint" {
        disable = false
        note    = "Make manual changes, continue for packaging"
    }
}

build {
    name = "upgrade"

    source "vagrant.macos11-vmware" {
    }

    # VMware Tools upload
    provisioner "file" {
        only = [
            "vagrant.macos1015-vmware",
            "vagrant.macos11-vmware"
        ]
        source = "/Applications/VMware Fusion.app/Contents/Library/isoimages/darwin.iso"
        destination = "/tmp/darwin.iso"
    }
    provisioner "shell" {
        only = [
            "vagrant.macos1015-vmware",
            "vagrant.macos11-vmware"
        ]
        script = "macos/vmware_tools_prepare.sh"
    }

    # basic system setup and OS update
    provisioner "shell" {
        scripts = [
            "macos/os_upgrade.sh"
        ]
        environment_vars = ["MINICOIN_OS_UPGRADE=11.2"]
        expect_disconnect = true
        start_retry_timeout = "1h"
    }

    provisioner "breakpoint" {
        disable = false
        note    = "OS upgrade script completed; finish installation, shut down, and run 'vagrant up source'"
    }

    provisioner "shell" {
        script = "macos/sudo.sh"
    }

    provisioner "shell" {
        only = [
            "vagrant.macos1015-vmware",
            "vagrant.macos11-vmware"
        ]
        script = "macos/vmware_tools.sh"
        expect_disconnect = true
        start_retry_timeout = "1h"
    }

    provisioner "breakpoint" {
        disable = false
        note    = "Complete VMware Tools installation and allow machine to reboot"
    }
}

build {
    name = "update"

    sources = [
        "vagrant.macos1015-virtualbox", 
        "vagrant.macos11-virtualbox",
        "vagrant.macos1015-vmware",
        "vagrant.macos11-vmware"
    ]

    # basic system setup and OS update
    provisioner "shell" {
        scripts = [
            "macos/sudo.sh",
            "macos/ssh.sh",
            "macos/softwareupdate.sh",
            "macos/softwareupdate_wait.sh",
            "macos/sudo.sh"
        ]
        expect_disconnect = true
        start_retry_timeout = "1h"
    }

    # updated command line tools, might require user interaction
    provisioner "shell" {
        script = "macos/xcode.sh"
    }

    # auto-login user vagrant
    provisioner "file" {
        source = "macos/kcpassword"
        destination = "/tmp/kcpassword"
    }
    provisioner "shell" {
        inline = [ 
            "sudo chown root /tmp/kcpassword",
            "sudo mv /tmp/kcpassword /etc/kcpassword",
            "sudo /usr/bin/defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser vagrant"
        ]
    }

    # software updates and installations
    provisioner "shell" {
        scripts = [
            "macos/brewupdate.sh",
            "macos/cmake.sh"
        ]
    }

    provisioner "shell" {
        script = "macos/sshfs.sh"
        only =[ 
            "vagrant.macos1015-virtualbox",
            "vagrant.macos11-virtualbox"
        ]
    }

    provisioner "breakpoint" {
        disable = false
        note    = "Update complete, check the machine for errors before packaging!"
    }

    # remove temporary files, zero out free space
    provisioner "shell" {
        script = "macos/cleanup.sh"
    }

    provisioner "breakpoint" {
        disable = false
        note    = "Update complete, check the machine for errors before packaging!"
    }
}
