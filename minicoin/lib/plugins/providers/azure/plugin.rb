require 'json'
require 'open3'

$AZURE_PROFILE = nil
$AZURE_CREDENTIALS = nil
$AZURE_CLI_INSTALLED = nil

if $AZURE_CLI_INSTALLED.nil?
    begin
        `az version`
        $AZURE_CLI_INSTALLED = true
    rescue
        $AZURE_CLI_INSTALLED = false
    end
end

module VagrantPlugins
    module Azure
        class Provider < Vagrant.plugin("2", :provider)
            @@azure_cli = Which.which("az")
            def self.check_cli()
                @@azure_cli
            end

            def prepare_account(machine)
            end

            def auto_shutdown(machine)
            end
        end
    end
end

module Minicoin
    module AzureExtensions
        class Plugin < Vagrant.plugin("2")
            name "Minicoin extensions for Azure"
            def self.minicoin_extension(provider)
                Extension if provider == :azure
            end
            # Azure specific settings
            def self.minicoin_setup(box, machine)
                return unless Vagrant.has_plugin?('vagrant-azure')
                return unless VagrantPlugins::Azure::Provider::check_cli()
                # this has to happen on machine level, even though it's only needed for the
                # provider, otherwise the plugin runs after machine-level provisioners, which
                # is too late.
                admin_password = ENV['AZURE_VM_ADMIN_PASSWORD'] || "$Vagrant(0)"
                box.vm.synced_folder "", "/azure", type: :cloud_prepare, id: :azure, admin_password: admin_password

                box.vm.provider :azure do |azure, override|
                    location = "northeurope"
                    pwd = ENV['minicoin_key']

                    override.vm.synced_folder ".", "/opt/minicoin", disabled: true
                    shared_folder = box.minicoin.actual_shared_folders
                    shared_folder.each do |host, guest|
                        override.vm.synced_folder host, guest, disabled: true
                    end
                    if $AZURE_PROFILE.nil?
                        stdout, stderr, status = Open3.capture3('az account show')
                        if status != 0
                            $AZURE_PROFILE = {}
                            $AZURE_CREDENTIALS = {}
                            STDERR.puts "Azure CLI installed, but failed to get azure account information."
                            STDERR.puts "Make sure you are logged in with 'az login'"
                            next
                        end
                        $AZURE_PROFILE = JSON.parse(stdout)
                        azure_clientname = "http://minicoin-azure"
                        stdout, stderr, status = Open3.capture3("az ad sp show --id \"#{azure_clientname}\"")
                        if status != 0
                            unless stderr.start_with?("Please ensure you have network connection")
                                stdout, stderr, status = Open3.capture3("az ad sp create-for-rbac --name '#{azure_clientname}'")
                                stdout, stderr, status = Open3.capture3("az ad sp credential reset --name '#{azure_clientname}' --password #{pwd}")
                                STDERR.puts "Failed to generate azure account credentials" if status != 0
                            end
                        end
                        $AZURE_CREDENTIALS = JSON.parse(stdout) if status == 0
                    end

                    next if $AZURE_CREDENTIALS.nil?

                    override.ssh.private_key_path = "~/.ssh/id_rsa"
                    override.ssh.keep_alive = true

                    if machine["os"] == "windows"
                        # open up for ssh, winrm, and rdp
                        azure.tcp_endpoints = [ '22', '5985', '5986', '3389' ]
                        override.winrm.transport = :negotiate
                        override.winrm.basic_auth_only = false
                        override.winrm.timeout = 3600
                        override.winssh.private_key_path = "~/.ssh/id_rsa"
                        override.winssh.keep_alive = true
                        begin # windows hostnames can't be more than 15 character long
                            vm_name = ""
                            loop do
                                vm_name = Haikunator.haikunate(100)
                                break if vm_name.length() <= 15
                            end
                            azure.vm_name = vm_name
                        rescue
                        end
                    end

                    azure.tenant_id = $AZURE_PROFILE["tenantId"]
                    azure.subscription_id = $AZURE_PROFILE["id"]
                    azure.client_id = $AZURE_CREDENTIALS["appId"]
                    azure.client_secret = pwd

                    azure.admin_username = "vagrant"
                    azure.location = location
                    azure.instance_ready_timeout = 3600

                    override.vagrant.sensitive = [ pwd ]
                end
            end
        end

        class Extension
            def provision(box, name, args, machine)
                return if args.nil?
                raise "Argument error: expecting args to be a hash" unless args.is_a?(Hash)
                box.vm.provider :azure do |azure, override|
                    args.each do |key, value|
                        if value.is_a?(Array) || value.is_a?(Hash)
                            eval("azure.#{key} = #{value}")
                        else
                            eval("azure.#{key} = \"#{value}\"")
                        end
                    end
                end
            end
        end
    end
end
