require "vagrant"
require "vagrant/errors"

module Minicoin
    module SyncedFolderMutagen
        class SyncedFolder < Vagrant.plugin("2", :synced_folder)
            def initialize()
                super
            end

            def usable?(machine, raise_error=false)
                return true if SyncedFolderMutagen.mutagen_path() && File.exist?(SyncedFolderMutagen.public_key())
                return false if !raise_error
                raise Minicoin::Errors::MutagenNotFound if !SyncedFolderMutagen.mutagen_path()
                raise Minicoin::Errors::NoSshKey if !File.exist?(SyncedFolderMutagen.public_key())
            end

            def enable(machine, folders, opts)
                machine.ui.info "Setting up mutagen sync sessions..."
                stdout, stderr, status = SyncedFolderMutagen.call_mutagen(:list, machine.name)
                status = -1 if status == 0 && stdout.include?("No sessions found")
                if status == 0
                    # we have a running session, check if it includes all our alphas
                    folders.each do |id, folder_opts|
                        next if folder_opts[:type] != :mutagen
                        alpha = folder_opts[:hostpath]
                        status = -1 unless stdout.include?(alpha)
                    end
                end
                # mutagen sync sessions already created - resume them
                if status == 0
                    machine.ui.detail "Resetting existing sessions..."
                    SyncedFolderMutagen.call_mutagen("reset", machine.name)
                    SyncedFolderMutagen.call_mutagen("resume", machine.name)
                    return
                end

                # revoke the trust from any old keys we might have for this machine
                SyncedFolderMutagen.revoke_trust(machine)
                # make the guest trust the host's user
                SyncedFolderMutagen.upload_key(machine)

                command = "#{SyncedFolderMutagen.mutagen_path} sync create --sync-mode one-way-replica --name minicoin --label minicoin=#{machine.name}"
                folders.each do |id, folder_opts|
                    next if folder_opts[:type] != :mutagen
                    alpha = folder_opts[:hostpath]
                    beta = folder_opts[:guestpath]
                    mount_options = folder_opts[:mount_options] || []
                    mount_options.each do |mount_option|
                        command += " #{mount_option}"
                    end
                    
                    machine.ui.detail "#{alpha} => #{beta}"
                    Vagrant.global_logger.debug("Ensuring beta path exists")
                    machine.communicate.execute("mkdir -p #{beta}")
                    Vagrant.global_logger.debug("Creating sync session with command '#{command}'")
                    stdout, stderr, status = Open3.capture3("echo yes | #{command} #{alpha} #{machine.ssh_info[:remote_user]}@#{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}:#{beta}")
                    if status != 0
                        machine.ui.warn("Attempting workaround to set up mutagen sync to #{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}: #{stderr}")
                        upload_mutagen_agent(machine)
                        stdout, stderr, status = Open3.capture3("echo yes | #{command} #{alpha} #{machine.ssh_info[:remote_user]}@#{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}:#{beta}")
                    end

                    if status != 0
                        machine.ui.error("Error setting up mutagen sync to #{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}: #{stderr}")
                        raise Minicoin::Errors::MutagenSyncFail
                    end
                end
            end

            def disable(machine, folders, opts)
                folders.each do |id, folder_opts|
                    alpha = folder_opts[:hostpath]
                    beta = folder_opts[:guestpath]
                    machine.ui.warn "#{alpha} =/= #{beta} not implemented"
                end
            end

            def cleanup(machine, opts)
                if machine.state.id == :not_created
                    # machine is being destroyed
                    ssh_info = machine.ssh_info || {}
                    if ssh_info[:host].nil?
                        ssh_info[:host], ssh_info[:port] = SyncedFolderMutagen.find_guest(machine)
                    end
                    SyncedFolderMutagen.call_mutagen("terminate", machine.name)
                    unless ssh_info[:host].nil?
                        machine.ui.info "Deauthorizing guest..."
                        if !SyncedFolderMutagen.remove_known_host(ssh_info)
                            machine.ui.error("Failed to remove SSH key for #{SyncedFolderMutagen.ssh_hostname(ssh_info)}")
                        end
                    end
                end
            end

            private

            # work around mutagen bug with Windows 20H2's OpenSSH server
            def upload_mutagen_agent(machine)
                if machine.config.vm.guest != :windows
                    machine.ui.error("Workaround not implemented for #{machine.config.vm.guest}")
                    return
                end
                agent_binary = "windows_amd64"

                mutagen_exe = SyncedFolderMutagen.mutagen_path()
                if File.symlink?(mutagen_exe)
                    mutagen_link = mutagen_exe
                    mutagen_exe = File.readlink(mutagen_exe)
                    unless mutagen_exe.start_with?("/") # relative path, resolve
                        mutagen_exe = File.realpath("#{File.dirname(mutagen_link)}/#{mutagen_exe}")
                    end
                end
                stdout, stderr, status = Open3.capture3("#{mutagen_exe} version")
                mutagen_version = stdout.strip
                mutagen_bin = File.dirname(mutagen_exe)
                machine.ui.info("mutagen at #{mutagen_bin} is version #{mutagen_version}")
                mutagen_agents = File.join(File.dirname(mutagen_bin), "libexec", "mutagen-agents.tar.gz")
                if File.exist?(mutagen_agents)
                    machine.ui.info("Extracting #{agent_binary} from #{mutagen_agents}")
                    `cd /tmp; tar -zxvf #{mutagen_agents} #{agent_binary}`
                    if File.exist?("/tmp/#{agent_binary}")
                        machine.ui.info("Uploading #{agent_binary} to #{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}")
                        machine.communicate.upload("/tmp/#{agent_binary}", "../.mutagen/agents/#{mutagen_version}/mutagen-agent.exe")
                    else
                        machine.ui.error("#{agent_binary} not present")
                    end
                end
            end
        end
    end
end
