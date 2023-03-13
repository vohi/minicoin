require "vagrant"
require "vagrant/errors"

module Minicoin
    module SyncedFolderMutagen
        class SyncedFolder < Vagrant.plugin("2", :synced_folder)
            def initialize()
                super
            end

            def pause(machine)
                stdout, stderr, status = SyncedFolderMutagen.call_mutagen("pause", machine.name)
                if status != 0
                    machine.ui.error stderr.strip
                end
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
                status = -1 if status == 0 && !stdout.include?("minicoin: #{machine.name}")
                # if the ssh info of the machine has changed, then we need to terminate and recreate
                if status == 0 && !stdout.include?("URL: #{machine.ssh_info[:remote_user]}@#{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}")
                    machine.ui.detail "SSH connection has changed, terminating old sync session..."
                    SyncedFolderMutagen.call_mutagen("terminate", machine.name)
                    status = -1
                end
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

                options_string = " --label minicoin=#{machine.name} --name minicoin-#{machine.name}"
                command = "#{SyncedFolderMutagen.mutagen_path} sync create --sync-mode one-way-replica #{options_string}"
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
                    begin
                        machine.communicate.execute("mkdir -p #{beta}")
                    rescue
                        machine.ui.warn "Creating the directory #{beta} failed, it probably already exists - skipping this session"
                        return
                    end
                    fullCommand = "echo yes | #{command} #{alpha} #{machine.ssh_info[:remote_user]}@#{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}:#{beta}"
                    Vagrant.global_logger.debug("Creating sync session with command '#{fullCommand}'")
                    stdout, stderr, status = Open3.capture3(fullCommand)
                    if status != 0 && command.start_with?("C:/") && stderr.include?("C:")
                        machine.ui.warn("Error calling mutagen, trying again with cmd-compliant command line...")
                        fullCommand.gsub!('/', '\\')
                        stdout, stderr, status = Open3.capture3(fullCommand)
                    end
                    # mutagen bug: fails to start the agent when the beta's login shell is powershell. So try
                    # to work around this bug by setting the login shell to cmd.exe, which will then be reverted
                    # by the default provisioning for Windows hosts.
                    if status != 0 && machine.guest.name == :windows && stderr.include?("CommandNotFoundException")
                        machine.ui.warn("Retrying with cmd.exe as login shell...")
                        machine.communicate.execute('New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\system32\cmd.exe" -PropertyType String -Force')
                        stdout, stderr, status = Open3.capture3(fullCommand)
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
        end
    end
end
