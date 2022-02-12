require 'json'

module Minicoin
    module Commands
        class AWS < Vagrant.plugin("2", :command)
            def self.synopsis
                "Manage AWS instances"
            end

            def self.echo(ui, type, data)
                data.chomp! # remove trailing newlines
                if type == :stderr
                    ui.error data
                else
                    ui.success data
                end
            end

            def initialize(argv, env)
                @argv, @sub, @sub_args = split_main_and_subcommand(argv)
                super(@argv, env)

                @subcommands = Vagrant::Registry.new
                @subcommands.register(:instance) do
                    Instance
                end
                @subcommands.register(:package) do
                    Package
                end
                @subcommands.register(:prune) do
                    PruneSecurityGroup
                end
            end

            def execute()
                options = {
                    env: []
                }

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin aws <subcommand> [name|id]"
                    option.separator ""
                    option.separator "Available subcommands:"
                    option.separator ""
                    @subcommands.each do |key, klass|
                        option.separator "     #{key.to_s.ljust(31)} #{klass.synopsis}"
                    end
                    option.separator ""
                    option.separator "For help with any individual subcommand run `minicoin mutagen <subcommand> -h"
                    option.separator ""
                end
                argv = parse_options(parser)
                return if !argv
                # argv will be [] but not nil if there's a subcommand

                command_class = @subcommands.get(@sub.to_sym) if @sub
                return @env.ui.info(parser.help) if !command_class || !@sub
                command_class.new(@sub_args, @env).execute
            end
        end

        class Instance < Vagrant.plugin("2", :command)
            def self.synopsis
                "Print the instance ID of the machine"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin aws instance [options] [name|id]"
                    option.separator ""
                    option.separator Instance::synopsis
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                    option.on("--json", "Enable output as JSON") do
                        options[:format] = :json
                    end
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    ui_options = { :target => vm.name }
                    ui_options = { :prefix => false } if @env.ui.is_a?(Vagrant::UI::MachineReadable)
                    if vm.box.provider != :aws
                        vm.ui.error "This machine is not backed by the AWS provider (#{vm.box.provider})", **ui_options
                    elsif !vm.id
                        vm.ui.error "The machine hasn't been created", **ui_options
                    else
                        if options[:format] == :json
                            data = {
                                "InstanceId" => vm.id
                            }
                            STDOUT.puts data.to_json
                        else
                            vm.ui.machine("instance-id", "#{vm.id}", **ui_options)
                            vm.ui.info vm.id, **ui_options
                        end
                    end
                end
            end
        end

        class Package < Vagrant.plugin("2", :command)
            def self.synopsis
                "Package the instance into a new AMI"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin aws package [options] [name|id]"
                    option.separator ""
                    option.separator Instance::synopsis
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                    option.on("--clean", "Clean the running instance before packaging") do
                        options[:clean] = true
                    end
                    option.on("--json", "Enable output as JSON") do
                        options[:format] = :json
                    end
                    option.on("--name NAME", "Specify the name of the AMI") do |o|
                        options[:name] = o
                    end
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    ui_options = { :target => vm.name }
                    ui_options = { :prefix => false } if @env.ui.is_a?(Vagrant::UI::MachineReadable)

                    if options[:clean]
                        if vm.state.id != :running
                            vm.ui.error "Instance is not running and cannot be cleaned before packaging; skipping"
                            next
                        end
                        vm.ui.info "Pausing all mutagen syncs and deleting betas..."
                        vm.synced_folders[:mutagen].each do |guest, synced_folder|
                            vm.ui.detail guest
                            synced_folder[:plugin].pause(vm)
                            if vm.guest.name == :windows
                                vm.communicate.execute("if (Test-Path '#{guest}') { Remove-Item '#{guest}' -Force -Recurse }")
                            else
                                vm.communicate.execute("rm -rf #{guest}")
                            end
                        end
                        vm.ui.info "Cleaning up disk space before packaging..."
                        if vm.guest.name == :windows
                            vm.communicate.execute('if (Test-Path "$env:USERPROFILE\\.mutagen") { Remove-Item "$env:USERPROFILE\\.mutagen" -Force -Recurse }')
                            vm.communicate.execute('Remove-Item @("$env:TEMP\\*", "$env:SystemRoot\\Temp\\*") -Force -Recurse')
                            vm.communicate.execute('Optimize-Volume -DriveLetter C -Defrag')
                            vm.communicate.execute('if (Get-Command sdelete64) { sdelete64 -z c: }')
                            vm.communicate.execute('Remove-Item "$env:ProgramData\\ssh\\administrators_authorized_keys" -Force')
                        else
                            vm.communicate.execute("rm -rf ~/.mutagen 2> /dev/null || true")
                            vm.communicate.execute("rm -rf /tmp/* || true")
                            vm.communicate.execute("cat /dev/zero > wipeout; rm wipeout")
                            vm.communicate.execute("rm ~/.ssh/authorized_keys 2> /dev/null || true")
                        end
                        vm.ui.detail "... done"
                    end

                    stdout, stderr, status = vm.provider.call(:ec2, "create-image", {
                        "instance-id" => vm.id,
                        :name => options[:name] || "minicoin packaged #{vm.name}"
                    })
                    if status != 0
                        vm.ui.error "Failed to create an AMI from #{vm.name}: #{stderr}", **ui_options
                    else
                        if options[:format] == :json
                            STDOUT.puts stdout
                        else
                            vm.ui.success "Package creation initiated: #{JSON.parse(stdout)["ImageId"]}", **ui_options
                        end
                    end
                end
            end
        end
        class PruneSecurityGroup < Vagrant.plugin("2", :command)
            def self.synopsis
                "Removes ingress rules for IP addresses other than the current public IP"
            end

            def initialize(argv, env)
                @env = env
                @argv = argv
            end

            def call(service, method, json={})
                VagrantPlugins::AWS::Provider.call(service, method, json)
            end

            def execute()
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin aws prune"
                    option.separator ""
                    option.separator PruneSecurityGroup::synopsis
                    option.separator ""
                end
                argv = parse_options(parser)
                unless argv == []
                    @env.ui.error "This command doesn't take any parameters or machine names"
                    @env.ui.error ""
                    @env.ui.info parser.help
                    return
                end

                stdout, stderr, status = call(:ec2, "describe-security-groups", {
                    "group-name" => "minicoin"
                })
                raise "Error reading security group: #{stderr}" if status != 0
                security_group_id = JSON.parse(stdout)["SecurityGroups"].first["GroupId"]
                @env.ui.info "Pruning security group #{security_group_id}"
                stdout, stderr, status = call(:ec2, "describe-security-group-rules", {
                    :filters => { "group-id" => security_group_id }
                })
                raise "Error reading security group rules: #{stderr}" if status != 0
                public_ip = Net::HTTP.get(URI("https://api.ipify.org"))
                @env.ui.info "Removing all ingress rules for CIDR blocks not including #{public_ip}"
                sg_rules = JSON.parse(stdout)["SecurityGroupRules"].select do |rule|
                    next if rule['IsEgress']
                    !IPAddr.new(rule['CidrIpv4']).include?(public_ip)
                end
                if sg_rules.empty?
                    @env.ui.success "No security groups removed"
                else
                    sg_rule_ids=[]
                    sg_rules.each do |rule|
                        sg_rule_ids << rule['SecurityGroupRuleId']
                    end
                    stdout, stderr, status = call(:ec2, "revoke-security-group-ingress", {
                        "group-id" => security_group_id,
                        "security-group-rule-ids" => sg_rule_ids.join(' ')
                    })
                    raise "Error reading security group rules: #{stderr}" if status != 0
                    @env.ui.success "#{sg_rule_ids.count} ingress rule(s) removed"
                end
            end
        end
    end
end
