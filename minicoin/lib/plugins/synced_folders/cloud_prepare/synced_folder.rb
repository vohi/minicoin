require 'json'

module Minicoin
    module CloudPrepare
        class SyncedFolder < Vagrant.plugin("2", :synced_folder)
            include Vagrant::Util

            def initialize()
                super
            end

            def usable?(machine, raise_error=false)
                # assume it's not one of the supported cloud providers; enable will not do anything
                return true unless machine.provider.class.methods(false).include?(:check_cli)
                return false unless machine.provider.class.check_cli()
                error_message = nil

                begin
                    machine.provider.prepare_account(machine)
                rescue => e
                    error_message = e
                end

                return true if !error_message
                if !raise_error
                    machine.ui.error error_message
                    return false
                end

                raise Minicoin::Errors::CloudNotReady.new(error_message)
            end

            def enable(machine, folders, opts)
                admin_password = ""
                folders.each do |id, folder_opts|
                    next if folder_opts[:type] != :cloud_prepare
                    admin_password = folder_opts[:admin_password]
                end

                return if machine.nil?
                folder = folders[machine.box.provider]
                return if folder.nil?
                if skip_prepare(machine)
                    machine.ui.output "#{machine.box.provider} machine already prepared, use the `--provision` flag to force a re-run."
                    return
                end
                machine.ui.output "Preparing #{machine.box.provider} machine #{machine.name} with minicoin requirements for #{machine.config.vm.guest}"

                # enable auto-shutdown, if implemented in our provider subclass
                machine.provider.auto_shutdown(machine)

                if machine.config.vm.guest == :windows
                    machine.ui.detail "Uploading data"
                    machine.communicate.upload("~/.ssh/id_rsa.pub", "c:\\Windows\\Temp\\id_rsa.pub")
                    machine.communicate.upload("./lib/cloud_provision", "C:\\Windows\\Temp")
                    machine.communicate.upload("./util", "c:\\opt\\minicoin")
                    machine.ui.detail "Installing base software"
                    machine.communicate.sudo("powershell.exe -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\cloud_provision\\windows.ps1 '#{admin_password}'") do |type, data|
                        echo(machine.ui, type, data)
                    end
                else
                    machine.ui.detail "Uploading scripts"
                    machine.communicate.sudo("echo \"127.0.0.1 $(hostname)\" >> /etc/hosts
                                              [ -d /opt/minicoin ] || sudo mkdir /opt/minicoin && sudo chown vagrant /opt/minicoin") do |type, data|
                        echo(machine.ui, type, data)
                    end
                    machine.communicate.upload("./util", "/opt/minicoin")
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
