$AWS_CLI_INSTALLED = nil

if $AWS_CLI_INSTALLED.nil?
    begin
        `aws --version`
        $AWS_CLI_INSTALLED = true
    rescue
        $AWS_CLI_INSTALLED = false
    end
end


# Azure specific settings
def aws_setup(box, machine)
    return unless Vagrant.has_plugin?('vagrant-aws')
    return if $AWS_CLI_INSTALLED == false
    # this has to happen on machine level, even though it's only needed for the
    # provider, otherwise the plugin runs after machine-level provisioners, which
    # is too late.
    # We need to somehow communicate the admin password to the machine's vagrant file,
    # and abusing a global environment variable seems to be the only way
    ENV['AWS_VM_ADMIN_PASSWORD'] = ENV['AWS_VM_ADMIN_PASSWORD'] || "#(#{ENV['minicoin_key']})"
    box.vm.synced_folder "", "/aws", type: :cloud_prepare, id: :aws, admin_password: ENV['AWS_VM_ADMIN_PASSWORD']

    box.vm.provider :aws do |aws, override|
         # this group is created by minicoin with permissions for SSH, RDP, and WinRM
        aws.security_groups = [ "minicoin" ]

        # hello Ireland
        aws.region = "eu-west-1"
        # 8 vCPU, 32 GB RAM
        aws.instance_type = "t2.2xlarge" unless box.vm.guest == :darwin

        # we need more disk space
        aws.block_device_mapping = [{
            "DeviceName" => "/dev/sda1",
            "Ebs.VolumeSize" => 50
        }]

        # destroying an instance is broken in the vagrant plugin, so we
        # always terminate when the instance is shut down via `vagrant halt`
        aws.terminate_on_shutdown = true

        # disable all folder sharing, it makes no sense for a machine in the cloud
        override.vm.synced_folder ".", "/minicoin", disabled: true
        shared_folder = box.minicoin.actual_shared_folders
        shared_folder.each do |host, guest|
            override.vm.synced_folder host, guest, disabled: true
        end

        # the default user in the VM is not vagrant, so we have to set that explicitly
        override.ssh.username = "vagrant"
        override.winrm.username = "vagrant"
        override.winrm.password = ENV['AWS_VM_ADMIN_PASSWORD']

        # prevent session timeouts
        override.ssh.keep_alive = true
        override.winssh.keep_alive = true

        # don't allow plain text authentication to a cloud provider
        override.winrm.transport = :negotiate
        override.winrm.basic_auth_only = false
        override.winrm.timeout = 3600
        override.winrm.ssl_peer_verification = false

        override.vagrant.sensitive = [ ENV['AWS_VM_ADMIN_PASSWORD'] || "#(#{ENV['minicoin_key']})" ]
    end
end
