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
