module Minicoin
    module SyncedFolderSSHFS
        class Plugin < Vagrant.plugin("2")
            name "SSHFS syncing for darwin guests as a shared_folders plugin"
            synced_folder(:sshfs) do # default priority, but only usable where native isn't
                require_relative "synced_folder.rb"
                SyncedFolder
            end
        end
    end
end
