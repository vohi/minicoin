require 'socket'
require 'timeout'
require "log4r"

module Minicoin
    module SyncedFolderSSHFS
        class SyncedFolder < Vagrant.plugin("2", :synced_folder)

            def initialize()
                @hostname = Socket.gethostname
                @logger = Log4r::Logger.new("minicoin::sshfs")
                @authorized_keys = File.expand_path("~/.ssh/authorized_keys")
                super
            end
            # This plugin requires a local SSH server
            def usable?(machine, raise_error=false)
                provider = nil
                boxname = nil
                if machine.box.nil?
                    # box not yet available, make a guess
                    if machine.provider.class.to_s.downcase.include?("virtualbox")
                        provider = :virtualbox
                    else
                        provider = machine.provider.class
                    end
                    minicoin = Minicoin.get_config(machine)
                    boxname = minicoin.machine["box"]
                else
                    provider = machine.box.provider
                    boxname = machine.box.name
                end
                if provider != :virtualbox
                    @logger.debug "SSHFS mounting only needed on virtualbox"
                    return false
                end
                unless boxname =~ /macos/
                    @logger.debug "SSHFS mounting only needed for macOS guests"
                    return false
                end
                begin
                    Timeout::timeout(1) do
                    begin
                        s = TCPSocket.new("127.0.0.1", 22)
                        s.close
                    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                        raise Minicoin::SyncedFolderSSHFS::NOSSHServerOnHost if raise_error
                        machine.env.ui.error Minicoin::SyncedFolderSSHFS::NOSSHServerOnHost.new.error_message
                        return false
                    end
                end
                rescue Timeout::Error
                    raise Minicoin::SyncedFolderSSHFS::SSHConnectionTimeout if raise_error
                    machine.env.ui.error Minicoin::SyncedFolderSSHFS::SSHConnectionTimeout.new.error_message
                    return false
                end

                return true
            end

            def enable(machine, folders, opts)
                machine.ui.info "Mounting folders via SSHFS"
                begin
                    machine.communicate.execute("which sshfs")
                rescue
                    machine.ui.warn "SSHFS not found on guest"
                    raise
                end
                upload_keys(machine)
                mount_folders(machine, folders)
            end

            def cleanup(machine, opts)
                begin
                    File.open("#{@authorized_keys}.new", 'w') do |out|
                        out.chmod(File.stat(@authorized_keys).mode)
                        File.foreach(@authorized_keys) do |line|
                            if line =~ /minicoin@#{machine.name}/
                                machine.ui.info "De-authorising guest"
                            else
                                out.puts line
                            end
                        end
                    end
                    File.rename("#{@authorized_keys}.new", @authorized_keys)
                rescue => e
                    machine.ui.warn "Error clearing authorizations: #{e}"
                end
            end

            private

            def upload_keys(machine)
                name = machine.name
                key_filename = "#{machine.data_dir}/minicoin"

                # ensure users private key is on the guest for authenticating back to host
                if File.zero?(key_filename)
                    File.delete(key_filename)
                end
                if !File.file?(key_filename)
                    machine.ui.detail "Generating sshfs key pair and authorizing guest"
                    `ssh-keygen -f #{key_filename} -C minicoin@#{name} -q -N \"\"`
                    public_key = File.read("#{key_filename}.pub")
                    open(@authorized_keys, 'a') do |file|
                        file.puts "#{public_key}"
                    end
                    File.chmod(0600, @authorized_keys)
                    machine.communicate.upload(key_filename, ".ssh/#{@hostname}")
                end
            end

            def mount_folders(machine, folders)
                mount_lines = []
                folders.each do |id, folder|
                    host_path = folder[:hostpath]
                    guest_path = File.expand_path(folder[:guestpath])
                    guest_base = guest_path.split('/').last

                    if $is_windows_host
                        host_path = "/#{host_path}".gsub("\\", "/")
                    end

                    sshfs_options = \
                    "reconnect,allow_other,defer_permissions,cache=no," \
                    "IdentityFile=/Users/vagrant/.ssh/#{@hostname},StrictHostKeyChecking=no," \
                    "volname=#{guest_base}"

                    mount_lines << <<-BASH.chomp
                        if (! stat "#{guest_path}" | grep $HOST_IP 2> /dev/null > /dev/null)
                        then
                        >&2 echo "Preparing '#{guest_path}'"
                            mkdir -p '#{guest_path}' 2> /dev/null
                        fi
                        df "#{guest_path}" 2> /dev/null | grep $HOST_IP > /dev/null
                        if [[ ! $? -eq 0 ]]
                        then
                            echo "    #{host_path} => #{guest_path}"
                            sshfs -o #{sshfs_options} #{$USER}@${HOST_IP}:#{host_path} "#{guest_path}"
                            cd "#{guest_path}"
                        else
                            >&2 echo "'#{guest_path}' exists already"
                        fi
                    BASH
                end
                mount_command = <<-BASH.chomp
                    if [ ! -f /usr/local/bin/sshfs ]
                    then
                        >&2 echo "No sshfs, nothing to do"
                        exit 0
                    fi
                    chmod 0600 .ssh/#{@hostname}
                    export HOST_IP=$(echo $SSH_CONNECTION | cut -f 1 -d ' ')
                    >&2 echo "Connecting to $HOST_IP"
                    #{mount_lines.join("\n")}
                    >&2 echo "Connected"
                BASH
                begin
                    machine.communicate.sudo(mount_command) do |type, data|
                        if type == :stderr
                            @logger.info data.strip!
                        else
                            machine.ui.detail data.strip!
                        end
                    end
                rescue => e
                    machine.ui.error e
                end
            end
        end
    end
end
