require "open3"

module Vagrant
    module Errors
        class MutagenNotFound < VagrantError
            def error_message
                "Mutagen not found"
            end
        end
        class MutagenSyncFail < VagrantError
            def error_message
                "Mutagen failed to create the sync session"
            end
        end
    end
end

module Minicoin
    module SyncedFolderMutagen
        include Vagrant::Util

        @@mutagen_path = Which.which("mutagen")
        def self.mutagen_path
            @@mutagen_path
        end
        def self.call_mutagen(command, label, params=nil)
            Open3.capture3("#{SyncedFolderMutagen.mutagen_path} sync #{command} --label-selector minicoin=#{label} #{params}")
        end

        # returns the hostname used by the ssh tools
        def self.ssh_hostname(ssh_info)
            if ssh_info[:port] != 22
                hostname = "[#{ssh_info[:host]}]:#{ssh_info[:port]}"
            else
                hostname = ssh_info[:host]
            end
        end

        # removes the known host
        def self.remove_known_host(ssh_info)
            if ssh_info
                stdout, stderr, status = Open3.capture3("ssh-keygen -R #{self.ssh_hostname(ssh_info)}")
                Vagrant.global_logger.debug("ssh-keygen output:")
                Vagrant.global_logger.debug(stdout)
                Vagrant.global_logger.debug(stderr)
                if status != 0
                    machine.ui.warn("Failed to remove SSH key for #{ssh_info[:host]}:#{ssh_info[:port]}: #{stderr}")
                end
            end
        end

        class Plugin < Vagrant.plugin("2")
            name "Mutagen syncing as a shared_folders plugin"
            def initialize()
                super
            end

            synced_folder("mutagen") do
                require_relative "synced_folder.rb"
                SyncedFolder
            end

            action_hook("mutagen_suspend", :machine_action_suspend) do |hook|
                require_relative "actions.rb"
                hook.prepend(MutagenSuspend)
            end
            action_hook("mutagen_suspend", :machine_action_halt) do |hook|
                require_relative "actions.rb"
                hook.prepend(MutagenSuspend)
            end
            action_hook("mutagen_resume", :machine_action_destroy) do |hook|
                require_relative "actions.rb"
                hook.append(MutagenDestroy)
            end
            action_hook("mutagen_resume", :machine_action_resume) do |hook|
                require_relative "actions.rb"
                hook.append(MutagenResume)
            end
            action_hook("mutagen_resume", :machine_action_up) do |hook|
                require_relative "actions.rb"
                hook.append(MutagenResume)
            end
        end
    end
end
