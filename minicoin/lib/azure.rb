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
    if $AZURE_CLI_INSTALLED == false
        return
    end

    name = machine["name"]
    location = "northeurope"
    pwd = ENV['minicoin_key']

    azure_validate = lambda do |machine|
        # this runs after the machine has booted, but aborts provisioning
        # if it can't succed.
        if machine.box.provider == :azure
            exp_features = ENV["VAGRANT_EXPERIMENTAL"] || ""
            if !exp_features.include?("dependency_provisioners")
                machine.ui.error("Provisioning Azure machines requires the 'dependency_provisioners'
experimental vagrant feture to be enabled. Set the VAGRANT_EXPERIMENTAL
variable, and provision explicitly using 'minicoin provision #{name}'!")
                exit 1
            end
        end
    end
    box.vm.provision "azure_validate:#{name}",
        type: :local_command,
        code: azure_validate

    box.vm.provider :azure do |azure, override|
        override.vm.synced_folder ".", "/minicoin", disabled: true
        shared_folder = machine['actual_shared_folders'] || {}
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
                    if status != 0
                        STDERR.puts "Failed to generate azure account credentials"
                    end
                end
            end
            if status == 0
                $AZURE_CREDENTIALS = JSON.parse(stdout)
            end
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

        if machine["os"] == "windows"
            admin_password = ENV['AZURE_VM_ADMIN_PASSWORD'] || "$Vagrant(0)"
            override.vagrant.sensitive = [ admin_password, pwd ]
            admin_password = admin_password.gsub('$', '`$') # powershell escapism

            override.vm.provision "openssh_key",
                type: :file,
                before: :all,
                source: "~/.ssh/id_rsa.pub", destination: "c:\\programdata\\ssh\\administrators_authorized_keys"

            override.vm.provision "cloud_init (win)",
                type: :shell,
                before: :all,
                path: "./lib/cloud_provision/windows.ps1",
                args: [ "#{admin_password}" ],
                upload_path: "c:\\windows\\temp\\windows_init.ps1",
                privileged: true

            override.vm.provision "minicoin_init (win)",
                type: :file,
                before: :all,
                source: "./util", destination: "c:\\minicoin\\util"

        else
            override.vagrant.sensitive = [ pwd ]
            override.vm.provision "cloud_init (nix)",
                type: :shell,
                before: :all,
                inline: "
                    echo \"127.0.0.1 $(hostname)\" >> /etc/hosts
                    [ -d /minicoin ] || sudo mkdir /minicoin && sudo chown vagrant /minicoin
                ",
                upload_path: "/tmp/vagrant-shell/azure_init.sh"
            override.vm.provision "minicoin_init (nix)",
                type: :file,
                before: :all,
                source: "./util", destination: "/minicoin/util"
        end
    end
end
