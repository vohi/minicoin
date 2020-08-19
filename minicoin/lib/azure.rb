require 'json'
require 'open3'

# VirtualBox specific settings
def azure_setup(box, machine)
    return unless machine['provider'] == "azure"
    name = machine["name"]
    location = "northeurope"
    pwd = ENV['minicoin_key']
    box.vm.hostname = "#{name}.#{location}.cloudapp.azure.com"

    stdout, stderr, status = Open3.capture3('az account show')
    if status != 0
        throw "Failed to get azure account information"
    end
    azureProfile = JSON.parse(stdout)
    stdout, stderr, status = Open3.capture3('az ad sp show --id "http://minicoin"')
    if status != 0
        puts "Creating new credentials"
        stdout, stderr, status = Open3.capture3("az ad sp create-for-rbac --name 'http://minicoin'")
        stdout, stderr, status = Open3.capture3("az ad sp credential reset --name 'http://minicoin' --password #{pwd}")
    end
    if status != 0
        throw "Failed to Generate azure account credentials"
    end
    credentials = JSON.parse(stdout)

    box.vm.provider :azure do |azure, override|
        override.ssh.private_key_path = "~/.ssh/id_rsa"
        override.vm.box = "azure"
    
        azure.tenant_id = azureProfile["tenantId"]
        azure.subscription_id = azureProfile["id"]
        azure.client_id = credentials["appId"]
        azure.client_secret = pwd

        azure.vm_name = name
        azure.vm_image_urn = machine["box"]
        azure.admin_username = "vagrant"
        # azure.vm_password
        # azure.resource_group_name = "minicoin_#{name}"
        azure.location = location
        # azure.vm_size =
        # azure.vm_vhd_uri =
        # azure.vm_managed_image_id =
    end

    # enable mutagen syncing
    box.vm.provision "azure",
        type: "shell",
        inline: "[ -d /minicoin ] || sudo mkdir /minicoin && sudo chown vagrant /minicoin",
        upload_path: "/tmp/vagrant-shell/azure.sh"

    box.vm.provision "mutagen_init", type: :local_command,
        commands: [
            "ssh-keyscan #{box.vm.hostname} >> ~/.ssh/known_hosts",
            "mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin-#{name} #{$PWD} vagrant@#{box.vm.hostname}:/minicoin"
        ]

    box.trigger.before :destroy do |trigger|
        hostip, stderr, status = Open3.capture3("dig #{box.vm.hostname} +short")
        trigger.name = "Removing #{box.vm.hostname} from list of known hosts"
        known_hosts = "#{$HOME}/.ssh/known_hosts"
        trigger.ruby do |env, machine|
            stdout, stderr, status = Open3.capture3("mutagen sync terminate minicoin-#{name}")
            File.open("#{known_hosts}.new", 'w') do |out|
                out.chmod(File.stat(known_hosts).mode)
                File.foreach(known_hosts) do |line|
                    out.puts line unless line =~ /#{box.vm.hostname}/ || line =~ /#{hostip}/
                end
            end
            File.rename("#{known_hosts}.new", known_hosts)
        end
    end
end
