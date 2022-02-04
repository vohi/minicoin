module Minicoin
    module Commands
        class AWS < Vagrant.plugin("2", :command)
            def self.synopsis
                "Manage AWS instances"
            end

            def initialize(argv, env)
                @argv, @sub, @sub_args = split_main_and_subcommand(argv)
                super(@argv, env)

                @subcommands = Vagrant::Registry.new
                @subcommands.register(:instance) do
                    Instance
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
                    ui_options = {
                        :target => vm.name,
                        :channel => "foo",
                        :type => "box-name"
                    }
                    ui = @env.ui.is_a?(Vagrant::UI::MachineReadable) ? @env.ui : vm.ui
                    if vm.box.provider != :aws
                        ui.error "This machine is not backed by the AWS provider (#{vm.box.provider})", **ui_options
                    elsif !vm.id
                        ui.error "The machine hasn't been created", **ui_options
                    else
                        if options[:format] == :json
                            data = {
                                "InstanceId" => vm.id
                            }
                            STDOUT.puts data.to_json
                        else
                            ui.machine("box-name", "#{vm.id}", **ui_options)
                        end
                    end
                end
            end
        end
    end
end
