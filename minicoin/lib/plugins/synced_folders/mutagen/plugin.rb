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
        def self.parse_sessions(machine)
            stdout, stderr, status = self.call_mutagen("list", machine.name)
            machine.ui.error stderr if status != 0
            sessions = [].tap do |sessions|
                stdout.strip.split(/-{3,}/).each do |block|
                    next if block.empty?
                    sections = {}
                    section = nil
                    block.split("\n").each do |line|
                        line.rstrip!
                        next if line.empty?
                        md = /^([A-Za-z]+?):\s?(.*)$/.match(line)
                        if md
                            section = md[1]
                            sections[section] = md[2].nil? || md[2].empty? ? {} : md[2]
                        elsif sections[section].is_a?(Hash)
                            md = /^([A-Za-z\s]+?):\s(.*)$/.match(line.lstrip)
                            if md
                                sections[section][md[1]] = md[2]
                            else
                                machine.ui.error "Wrongly formatted data: #{line}"
                            end
                        else
                            machine.ui.error "Unexpected data: #{line}"
                        end
                    end
                    sessions << sections
                end
            end
            sessions
        end
        def self.find_guest(machine)
            sessions = self.parse_sessions(machine)
            return nil if sessions.empty?
            sessions.each do |session|
                beta = session["Beta"]["URL"]
                re = Regexp.new /(?<user>.*?)@(?<host>.*?):((?<port>.*?):)?(?<path>.*\/.*?)/
                matchdata = re.match(beta)
                if matchdata
                    user, host, port, path = matchdata.captures
                    return [ host, port ]
                end
            end
            nil # found nothing
        end

        def self.call_mutagen(command, label, params=nil)
            label_str = "--label-selector minicoin=#{label}" if label
            Open3.capture3("#{SyncedFolderMutagen.mutagen_path} sync #{command} #{label_str} #{params}")
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
            stdout, stderr, status = Open3.capture3("ssh-keygen -R #{self.ssh_hostname(ssh_info)}")
            Vagrant.global_logger.debug("ssh-keygen output:")
            Vagrant.global_logger.debug(stdout)
            Vagrant.global_logger.debug(stderr)
            return status == 0
        end

        class Plugin < Vagrant.plugin("2")
            name "Mutagen syncing as a shared_folders plugin"
            def initialize()
                super
            end

            synced_folder("mutagen", 9) do # lower priority than built-in
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
            action_hook("mutagen_resume", :machine_action_resume) do |hook|
                require_relative "actions.rb"
                hook.append(MutagenResume)
            end
            action_hook("mutagen_resume", :machine_action_up) do |hook|
                require_relative "actions.rb"
                hook.append(MutagenResume)
            end

            command(:mutagen) do
                require_relative "command.rb"
                Command
            end
        end
    end
end
