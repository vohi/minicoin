module Minicoin
    module SyncedFolderSSHFS
        class NOSSHServerOnHost < Vagrant::Errors::VagrantError
            def error_message
                "No SSH server detected on host, can't mount host folder!"
            end
        end
        class SSHConnectionTimeout < Vagrant::Errors::VagrantError
            def error_message
                "Connection to SSH server on host timed out"
            end
        end
        
        class Plugin < Vagrant.plugin("2")
            name "SSHFS syncing for darwin guests as a shared_folders plugin"
            synced_folder(:sshfs) do # default priority, but only usable where native isn't
                require_relative "synced_folder.rb"
                SyncedFolder
            end
        end
    end
end
