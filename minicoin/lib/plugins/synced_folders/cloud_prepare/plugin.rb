module Vagrant
    module Errors
        class CloudNotReady < VagrantError
            attr_accessor :message
            def initialize(m)
                @message = m
            end
            def error_message
                @message
            end
        end
    end
end


module Minicoin
    module CloudPrepare
        class Plugin < Vagrant.plugin("2")
            name "Abusing a shared_folder plugin to prepare VMs in the cloud"
# This is a vagrant bug - having multiple synced folder plugins displaces the default
# folder syncing functionality (e.g. virtualbox or vmware)
# Reported to vagrant as https://github.com/hashicorp/vagrant/issues/12208

#            synced_folder("cloud_prepare") do
#                require_relative "synced_folder.rb"
#                SyncedFolder
#            end
        end
    end
end
