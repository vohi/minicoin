require 'json'
require 'open3'

# VirtualBox specific settings
def azure_setup(box, machine)
    return unless machine['provider'] == "azure"
    name = machine["name"]
    location = "northeurope"
    pwd = ENV['minicoin_key']

    stdout, stderr, status = Open3.capture3('az account show')
    if status != 0
        raise "Failed to get azure account information"
    end
    azureProfile = JSON.parse(stdout)
    stdout, stderr, status = Open3.capture3('az ad sp show --id "http://minicoin"')
    if status != 0
        stdout, stderr, status = Open3.capture3("az ad sp create-for-rbac --name 'http://minicoin'")
        stdout, stderr, status = Open3.capture3("az ad sp credential reset --name 'http://minicoin' --password #{pwd}")
    end
    if status != 0
        raise "Failed to generate azure account credentials"
    end
    credentials = JSON.parse(stdout)

    box.vm.provider :azure do |azure, override|
        override.ssh.private_key_path = "~/.ssh/id_rsa"
        override.vm.box = "azure"
        override.vm.box_url = "https://github.com/azure/vagrant-azure/raw/v2.0/dummy.box"

        if machine["os"] == "windows"
            # open up for ssh, winrm, and rdp
            azure.tcp_endpoints = [ '22', '5985', '5986', '3389' ]
            override.winrm.transport = :negotiate
            override.winrm.basic_auth_only = false
            override.winssh.private_key_path = "~/.ssh/id_rsa"
        end

        if machine["box"].start_with?("/subscriptions/")
            azure.vm_managed_image_id = machine["box"]
        elsif machine["box"].end_with?(".vhd")
            azure.vm_vhd_uri = machine["box"]
            azure.vm_operating_system = machine["os"]
            # azure.vm_vhd_storage_account_id =
        else
            azure.vm_image_urn = machine["box"]
        end

        azure.tenant_id = azureProfile["tenantId"]
        azure.subscription_id = azureProfile["id"]
        azure.client_id = credentials["appId"]
        azure.client_secret = pwd

        azure.vm_image_urn = machine["box"]
        azure.admin_username = "vagrant"
        azure.location = location
        azure.instance_ready_timeout = 3600
        # setting the name can easily cause conflicts, and makes the vagrant box name subject to restrictions
        # azure.vm_name = name
        # all machines in the same resource_group_name will be destroyed when one of them is
        # azure.resource_group_name = "minicoin_#{name}"

        # azure.vm_password =
        # azure.vm_size =
        azure.wait_for_destroy = true
    end

    if machine["os"] == "windows"
        box.vm.provision "openssh_key",
            type: :file,
            source: "~/.ssh/id_rsa.pub", destination: "c:\\programdata\\ssh\\administrators_authorized_keys"
        box.vm.provision "minicoin_init",
            type: :file,
            source: "./util", destination: "c:\\minicoin\\util"
        box.vm.provision "windows_init",
            type: :shell,
            path: "./lib/cloud_provision/windows.ps1",
            upload_path: "c:\\windows\\temp\\windows_init.ps1",
            privileged: true
    else
        box.vm.provision "azure_init",
            type: :shell,
            inline: "
                echo \"127.0.0.1 #{name}\" >> /etc/hosts
                [ -d /minicoin ] || sudo mkdir /minicoin && sudo chown vagrant /minicoin
            ",
            upload_path: "/tmp/vagrant-shell/azure_init.sh"
        box.vm.provision "minicoin_init",
            type: :file,
            source: "./util", destination: "/minicoin/util"
    end
end
