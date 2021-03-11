module Minicoin
    module CloudPrepare
        class SyncedFolder < Vagrant.plugin("2", :synced_folder)
            include Vagrant::Util
            @@azure_cli = Which.which("az")
            def self.azure_cli()
                @@azure_cli
            end

            def initialize()
                super
            end

            def usable?(machine, raise_error=false)
                error_message = nil
                provider = nil
                if machine.box.nil?
                    # box not yet available, make a guess
                    if machine.provider.class.to_s == "VagrantPlugins::Azure::Provider"
                        provider = :azure
                    else
                        provider = machine.provider.class
                    end
                else
                    provider = machine.box.provider
                end
                if provider == :azure
                    if !SyncedFolder.azure_cli()
                        error_message = "The Azure CLI is not installed"
                    elsif !$AZURE_CREDENTIALS
                        error_message = "Failed to read Azure credentials"
                    end
                elsif provider == :aws
                    error_message = "AWS not implemented"
                else
                    error_message = "Unknown cloud provider #{provider}"
                end

                return true if !error_message
                if !raise_error
                    machine.ui.error error_message
                    return false
                end

                raise Minicoin::Errors::CloudNotReady.new(error_message)
            end

            def enable(machine, folders, opts)
                folder = folders[machine.box.provider]
                return if folder.nil?
                if skip_prepare(machine)
                    machine.ui.output "#{machine.box.provider} machine already prepared, use the `--provision` flag to force a re-run."
                    return
                end
                machine.ui.output "Preparing #{machine.box.provider} machine #{machine.name} with minicoin requirements for #{machine.config.vm.guest}"
                if machine.config.vm.guest == :windows
                    machine.ui.detail "Uploading data"
                    machine.communicate.upload("~/.ssh/id_rsa.pub", "c:\\programdata\\ssh\\administrators_authorized_keys")
                    machine.communicate.upload("./lib/cloud_provision", "C:\\Windows\\Temp")
                    machine.communicate.upload("./util", "c:\\minicoin\\util")
                    admin_password = ENV['AZURE_VM_ADMIN_PASSWORD'] || "$Vagrant(0)"
                    machine.ui.detail "Installing base software"
                    machine.communicate.sudo("powershell.exe -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\cloud_provision\\windows.ps1 '#{admin_password}'") do |type, data|
                        echo(machine.ui, type, data)
                    end
                else
                    machine.ui.detail "Uploading scripts"
                    machine.communicate.sudo("echo \"127.0.0.1 $(hostname)\" >> /etc/hosts
                                              [ -d /minicoin ] || sudo mkdir /minicoin && sudo chown vagrant /minicoin") do |type, data|
                        echo(machine.ui, type, data)
                    end
                    machine.communicate.upload("./util", "/minicoin/util")
                end
            end

            private

            def echo(ui, type, data)
                data.chomp! # remove trailing newlines
                if type == :stderr
                    ui.error data
                else
                    ui.success data
                end
            end

            def skip_prepare(machine)
                return false if ARGV.include?("--provision")
                # see Vagrant's provision.rb
                skip_prepare = false
                sentinel_path = machine.data_dir.join("action_provision")
                if sentinel_path.file?
                    contents = sentinel_path.read.chomp
                    parts = contents.split(":")
                    if parts.length == 1
                        skip_prepare = true
                    elsif parts[0] == "1.5"
                        skip_prepare = parts[1..] == machine.id.to_s.split(":")
                    end
                end
                skip_prepare
            end
        end
    end
end
