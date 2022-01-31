
class Hash
    def slice(*keep_keys)
        h = {}
        keep_keys.each { |key| h[key] = fetch(key) if has_key?(key) }
        h
    end unless Hash.method_defined?(:slice)
    def except(*less_keys)
        slice(*keys - less_keys)
    end unless Hash.method_defined?(:except)
end

$AWS_CLI_INSTALLED = nil

if $AWS_CLI_INSTALLED.nil?
    begin
        `aws --version`
        $AWS_CLI_INSTALLED = true
    rescue
        $AWS_CLI_INSTALLED = false
    end
end


# AWS specific settings
def aws_setup(box, machine)
    $settings[:aws_boxes] ||= []

    return unless Vagrant.has_plugin?('vagrant-aws')
    return if $AWS_CLI_INSTALLED == false
    # We need to somehow communicate the admin password to the machine's vagrant file,
    # and using an environment variable (or alternatively $settings) seems to be the only way,
    # and we want users to set the admin password for the machines anyway.
    aws_password = ENV['AWS_VM_ADMIN_PASSWORD'] || "#(#{ENV['minicoin_key']})"

    # this has to happen on machine level, even though it's only needed for the
    # provider, otherwise the plugin runs after machine-level provisioners, which
    # is too late.
    box.vm.synced_folder "", "/aws", type: :cloud_prepare, id: :aws, admin_password: aws_password

    box.vm.provider :aws do |aws, override|
         # this group is created by minicoin with permissions for SSH, RDP, and WinRM
        aws.security_groups = [ "minicoin" ]

        # Workaround for https://github.com/mitchellh/vagrant-aws/issues/538: if the box we
        # want is not installed yet, then the AWS plugin fails the validation before the box
        # gets downloaded and installed. To check whether the box is installed, we use an entry
        # in our global settings hash that boxes add themselves to via their Vagrantfile.
        # If the box is not loaded yet, then setting the ami to a dummy value satisfies the
        # plugin without overwriting the box file or the AWS-specific provisioning declared
        # in the minicoin machine configuration.
        aws.ami = "dummy" unless $settings[:aws_boxes].include?(box.minicoin.machine['box'])

        aws.tags = {
            "minicoin" => box.minicoin.machine['name']
        }

        # We expect that the user has a key pair in ~/.ssh
        begin
            public_key = File.read("#{$HOME}/.ssh/id_rsa.pub").strip
            override.ssh.private_key_path = "~/.ssh/id_rsa"
            override.winssh.private_key_path = "~/.ssh/id_rsa"
        rescue => e
            STDERR.puts "Failed to read the public key: #{e}"
        end

        # hello Ireland
        aws.region = "eu-west-1"

        user_data_file = "linux"
        user_data_file = box.vm.guest.to_s if box.vm.guest.is_a?(Symbol)
        begin
            user_data = File.read("./lib/cloud_provision/aws/#{user_data_file}.user_data").strip
            user_data.sub!('#{public_key}', public_key)
            user_data.sub!('#{aws_password}', aws_password)
            aws.user_data = user_data
        rescue => e
            STDERR.puts "Failed to read user data for AWS platform #{user_data_file}"
        end

        # destroying an instance is broken in the vagrant plugin, so we
        # always terminate when the instance is shut down via `vagrant halt`
        aws.terminate_on_shutdown = true

        # disable all folder sharing, it makes no sense for a machine in the cloud
        override.vm.synced_folder ".", "/opt/minicoin", disabled: true
        shared_folder = box.minicoin.actual_shared_folders
        shared_folder.each do |host, guest|
            override.vm.synced_folder host, guest, disabled: true
        end

        # the default user in the VM is not vagrant, so we have to set that explicitly
        override.ssh.username = "vagrant"
        override.winrm.username = "vagrant"
        override.winrm.password = aws_password

        # prevent session timeouts
        override.ssh.keep_alive = true
        override.winssh.keep_alive = true

        # don't allow plain text authentication to a cloud provider
        override.winrm.transport = :negotiate
        override.winrm.basic_auth_only = false
        override.winrm.timeout = 3600
        override.winrm.ssl_peer_verification = false

        override.vagrant.sensitive = [ aws_password ]
    end
end
