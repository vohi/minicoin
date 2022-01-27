require 'json'

module Minicoin
    module CloudPrepare
        class SyncedFolder < Vagrant.plugin("2", :synced_folder)
            include Vagrant::Util
            @@azure_cli = Which.which("az")
            @@aws_cli = Which.which("aws")
            @@aws_account = nil
            def self.azure_cli()
                @@azure_cli
            end
            def self.aws_cli()
                @@aws_cli
            end

            def initialize()
                super
            end

            def prepare_aws_account(machine)
                return nil unless @@aws_account.nil?
                return unless ['up', 'validate'].include?(ARGV[0]) # don't check AWS for check and shutdown operations
                begin
                    @@aws_account = "" # don't try again
                    # check that there are credentials
                    stdout, stderr, status = Open3.capture3('aws sts get-caller-identity')
                    raise "Failed to read AWS account information" if status != 0
                    aws_profile = JSON.parse(stdout)
                    @@aws_account = aws_profile['Account']
                    machine.ui.info "Verifying AWs account #{@@aws_account}"

                    # verify that there is a default VPC
                    stdout, stderr, status = Open3.capture3("aws ec2 describe-vpcs --filters Name=is-default,Values=true;Name=state,Values=available")
                    raise "Failed to read VPC information: #{stderr}" if status != 0
                    default_vpc = JSON.parse(stdout)['Vpcs'][0]
                    raise "No available default VPC found" if default_vpc.nil?
                    machine.ui.detail "Using Virtual private cloud #{default_vpc['VpcId']}"

                    # check if there's a minicoin security group, and create it if not
                    stdout, stderr, status = Open3.capture3("aws ec2 describe-security-groups --filters Name=group-name,Values=minicoin;Name=vpc-id,Values=#{default_vpc['VpcId']}")
                    raise "Failed to read security group information: #{stderr}" if status != 0
                    minicoin_group = JSON.parse(stdout)['SecurityGroups'][0]
                    if minicoin_group.nil?
                        machine.ui.detail "minicoin security group not found, creating..."
                        create_string = "--group-name 'minicoin' --description 'Default group for minicoin machines' --vpc-id '#{default_vpc['VpcId']}'"
                        stdout, stderr, status = Open3.capture3("aws ec2 create-security-group #{create_string}")
                        raise "Failed to create minicoin security group: #{stderr}" if status != 0
                        minicoin_group = JSON.parse(stdout)
                    end
                    machine.ui.detail "Machines will be created in security group #{minicoin_group['GroupId']}"
                    if minicoin_group['IpPermissions'].nil?
                        ports = [22, 3389, 5985, 5986] # Open up for SSH, RDP, and WinRM
                        machine.ui.detail "Security group has no ingress permissions, adding rules for ports"
                        ports.each do |port|
                            machine.ui.detail "... #{port}"
                            rule_string = "--ip-permissions \"FromPort=#{port},ToPort=#{port},IpProtocol=tcp,IpRanges=[{CidrIp='0.0.0.0/0',Description='Allow port #{port}'}]\""
                            stdout, stderr, status = Open3.capture3("aws ec2 authorize-security-group-ingress --group-id #{minicoin_group['GroupId']} #{rule_string}")
                            # don't throw, just warn and 
                            machine.ui.warn "Failed to add ingress rule for port #{port}: #{stderr}" if status != 0
                        end
                    end
                rescue => e
                    machine.ui.error e
                    return "The AWS account does not meet the minicoin requirements"
                end
                nil
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
                    if !SyncedFolder.aws_cli()
                        error_message = "The AWS CLI is not installed"
                    else
                        error_message = prepare_aws_account(machine)
                    end
                else
                    # assume it's not a cloud provider; enable will not do anything
                    return true
                end

                return true if !error_message
                if !raise_error
                    machine.ui.error error_message
                    return false
                end

                raise Minicoin::Errors::CloudNotReady.new(error_message)
            end

            def enable(machine, folders, opts)
                return if machine.nil?
                folder = folders[machine.box.provider]
                return if folder.nil?
                if skip_prepare(machine)
                    machine.ui.output "#{machine.box.provider} machine already prepared, use the `--provision` flag to force a re-run."
                    return
                end
                machine.ui.output "Preparing #{machine.box.provider} machine #{machine.name} with minicoin requirements for #{machine.config.vm.guest}"
                if machine.config.vm.guest == :windows
                    machine.ui.detail "Uploading data"
                    machine.communicate.upload("~/.ssh/id_rsa.pub", "c:\\Windows\\Temp\\id_rsa.pub")
                    machine.communicate.upload("./lib/cloud_provision", "C:\\Windows\\Temp")
                    machine.communicate.upload("./util", "c:\\minicoin")
                    admin_password = ENV['CLOUD_VM_ADMIN_PASSWORD'] || "vagrant"
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
                    machine.communicate.upload("./util", "/minicoin")
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
