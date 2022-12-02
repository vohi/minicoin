require "open3"

module Minicoin
    module SyncedFolderMutagen
        include Vagrant::Util

        @@mutagen_path = "#{Platform.unix_windows_path(Which.which("mutagen"))}"
        def self.mutagen_path
            @@mutagen_path
        end
        def self.public_key
            "#{$HOME}/.ssh/id_rsa.pub"
        end
        def self.upload_key(machine)
            if machine.config.vm.guest == :windows
                mutagen_key_destination = ".ssh\\#{$USER}.pub"
                mutagen_key_destination = "..\\#{mutagen_key_destination}" if machine.config.vm.communicator == :winrm
                mutagen_key_add = "Get-Content -Path $env:USERPROFILE\\.ssh\\#{$USER}.pub | Add-Content -Path $env:USERPROFILE\\.ssh\\authorized_keys -Encoding utf8"
            else
                mutagen_key_destination = ".ssh/#{$USER}.pub"
                mutagen_key_add = "cat #{mutagen_key_destination} >> .ssh/authorized_keys"
            end
            begin
                machine.communicate.upload(SyncedFolderMutagen.public_key(), mutagen_key_destination)
                machine.communicate.execute(mutagen_key_add)
            rescue => e
                machine.ui.error "Failed to authorize host key: #{e}"
                raise Minicoin::Errors::NoSshKey
            end
        end
        def self.revoke_trust(machine, force=false)
            return if !machine.ssh_info

            ssh_hostname = SyncedFolderMutagen.ssh_hostname(machine.ssh_info)
            Vagrant.global_logger.debug("Finding registered key for #{ssh_hostname}")
            stdout, stderr, status = Open3.capture3("ssh-keygen -F #{ssh_hostname}")
            ssh_registered = stdout.strip.split("\n")
            Vagrant.global_logger.debug("No keys registered for #{ssh_hostname}")
            return if ssh_registered.empty?

            Vagrant.global_logger.debug("Scanning key from #{machine.ssh_info}")
            stdout, stderr, status = Open3.capture3("ssh-keyscan -4 -p #{machine.ssh_info[:port]} #{machine.ssh_info[:host]}")
            if status != 0
                machine.ui.warn("Couldn't scan public key from #{machine.name}")
            else
                if (stdout.strip.split("\n") & ssh_registered).empty? || force
                    machine.ui.warn("Guest's host identification changed, revoking old keys for #{ssh_hostname}") unless force
                    stdout, stderr, status = Open3.capture3("ssh-keygen -R #{ssh_hostname}")
                end
            end
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
                                Vagrant.global_logger.debug "Wrongly formatted data: #{line}"
                            end
                        end
                    end
                    sessions << sections unless sections.empty?
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

            action_hook("mutagen_destroy", :machine_action_destroy) do |hook|
                require_relative "actions.rb"
                hook.prepend(MutagenDestroy)
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
