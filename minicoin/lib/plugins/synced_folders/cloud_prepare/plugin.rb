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
            synced_folder("cloud_prepare", 1) do # low priority
                require_relative "synced_folder.rb"
                SyncedFolder
            end
        end
    end
end
