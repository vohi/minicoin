module Minicoin
    module SyncedFolderSSHFS
        class NOSSHServerOnHost < Vagrant::Errors::VagrantError
            attr_accessor :message
            def initialize(m)
                @message = m
            end
            def error_message
                @message
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
