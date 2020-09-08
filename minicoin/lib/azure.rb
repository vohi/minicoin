require 'json'
require 'open3'

$AZURE_PROFILE = nil
$AZURE_CREDENTIALS = nil

# VirtualBox specific settings
def azure_setup(box, machine)
    name = machine["name"]
    location = "northeurope"
    pwd = ENV['minicoin_key']

    box.vm.provider :azure do |azure, override|
        override.vm.synced_folder ".", "/minicoin", disabled: true
        unless machine['actual_shared_folders'].nil?
            machine['actual_shared_folders'].each do |shared_folder|
                shared_folder.each do |host, guest|
                    override.vm.synced_folder host, guest, disabled: true
                end
            end
        end
        if $AZURE_PROFILE.nil?
            stdout, stderr, status = Open3.capture3('az account show')
            if status != 0
                raise "Failed to get azure account information"
            end
            $AZURE_PROFILE = JSON.parse(stdout)
            stdout, stderr, status = Open3.capture3('az ad sp show --id "http://minicoin"')
            if status != 0
                stdout, stderr, status = Open3.capture3("az ad sp create-for-rbac --name 'http://minicoin'")
                stdout, stderr, status = Open3.capture3("az ad sp credential reset --name 'http://minicoin' --password #{pwd}")
            end
            if status != 0
                raise "Failed to generate azure account credentials"
            end
            $AZURE_CREDENTIALS = JSON.parse(stdout)
        end
        
        override.ssh.private_key_path = "~/.ssh/id_rsa"

        if machine["os"] == "windows"
            # open up for ssh, winrm, and rdp
            azure.tcp_endpoints = [ '22', '5985', '5986', '3389' ]
            override.winrm.transport = :negotiate
            override.winrm.basic_auth_only = false
            override.winssh.private_key_path = "~/.ssh/id_rsa"
        end

        azure.tenant_id = $AZURE_PROFILE["tenantId"]
        azure.subscription_id = $AZURE_PROFILE["id"]
        azure.client_id = $AZURE_CREDENTIALS["appId"]
        azure.client_secret = pwd

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
        admin_password = ENV['AZURE_VM_ADMIN_PASSWORD'] || "$Vagrant(0)"
        admin_password = admin_password.gsub('$', '`$') # powershell escapism

        box.vm.provision "windows_init",
            type: :shell,
            path: "./lib/cloud_provision/windows.ps1",
            args: [ "#{admin_password}" ],
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
