# Azure specific settings
def aws_setup(box, machine)
    return unless Vagrant.has_plugin?('vagrant-aws')
    # this has to happen on machine level, even though it's only needed for the
    # provider, otherwise the plugin runs after machine-level provisioners, which
    # is too late.
    box.vm.synced_folder "", "/aws", type: :cloud_prepare, id: :aws

    box.vm.provider :aws do |aws, override|
        override.vm.synced_folder ".", "/minicoin", disabled: true
        shared_folder = box.minicoin.actual_shared_folders
        shared_folder.each do |host, guest|
            override.vm.synced_folder host, guest, disabled: true
        end
        override.ssh.private_key_path = "~/.ssh/id_rsa"
        override.ssh.keep_alive = true
    end
end
