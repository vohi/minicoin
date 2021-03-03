require 'json'
require 'open3'

$AZURE_PROFILE = nil
$AZURE_CREDENTIALS = nil
$AZURE_CLI_INSTALLED = nil

if $AZURE_CLI_INSTALLED.nil?
    begin
        `az version`
        $AZURE_CLI_INSTALLED = true
    rescue
        $AZURE_CLI_INSTALLED = false
    end
end

# Azure specific settings
def azure_setup(box, machine)
    return unless Vagrant.has_plugin?('vagrant-azure')
    return if $AZURE_CLI_INSTALLED == false

    box.vm.provider :azure do |azure, override|
        location = "northeurope"
        pwd = ENV['minicoin_key']

        override.vm.synced_folder "", "/azure", type: :cloud_prepare, id: :azure
        override.vm.synced_folder ".", "/minicoin", disabled: true
        shared_folder = box.minicoin.actual_shared_folders
        shared_folder.each do |host, guest|
            override.vm.synced_folder host, guest, disabled: true
        end
        if $AZURE_PROFILE.nil?
            stdout, stderr, status = Open3.capture3('az account show')
            if status != 0
                $AZURE_PROFILE = {}
                $AZURE_CREDENTIALS = {}
                STDERR.puts "Azure CLI installed, but failed to get azure account information."
                STDERR.puts "Make sure you are logged in with 'az login'"
                next
            end
            $AZURE_PROFILE = JSON.parse(stdout)
            stdout, stderr, status = Open3.capture3('az ad sp show --id "http://minicoin"')
            if status != 0
                unless stderr.start_with?("Please ensure you have network connection")
                    stdout, stderr, status = Open3.capture3("az ad sp create-for-rbac --name 'http://minicoin'")
                    stdout, stderr, status = Open3.capture3("az ad sp credential reset --name 'http://minicoin' --password #{pwd}")
                    STDERR.puts "Failed to generate azure account credentials" if status != 0
                end
            end
            $AZURE_CREDENTIALS = JSON.parse(stdout) if status == 0
        end

        next if $AZURE_CREDENTIALS.nil?

        override.ssh.private_key_path = "~/.ssh/id_rsa"

        if machine["os"] == "windows"
            # open up for ssh, winrm, and rdp
            azure.tcp_endpoints = [ '22', '5985', '5986', '3389' ]
            override.winrm.transport = :negotiate
            override.winrm.basic_auth_only = false
            override.winrm.timeout = 3600
            override.winssh.private_key_path = "~/.ssh/id_rsa"
            begin # windows hostnames can't be more than 15 character long
                vm_name = ""
                loop do
                    vm_name = Haikunator.haikunate(100)
                    break if vm_name.length() <= 15
                end
                azure.vm_name = vm_name
            rescue
            end
        end

        azure.tenant_id = $AZURE_PROFILE["tenantId"]
        azure.subscription_id = $AZURE_PROFILE["id"]
        azure.client_id = $AZURE_CREDENTIALS["appId"]
        azure.client_secret = pwd

        azure.admin_username = "vagrant"
        azure.location = location
        azure.instance_ready_timeout = 3600

        override.vagrant.sensitive = [ ENV['AZURE_VM_ADMIN_PASSWORD'] || "$Vagrant(0)", pwd ]
    end
end
