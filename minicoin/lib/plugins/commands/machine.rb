require 'json'
require 'fileutils'

module Minicoin
    module Commands
        class Machine < Vagrant.plugin("2", :command)
            def self.synopsis
                "Manage minicoin machines"
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
                @subcommands.register(:list) do
                    List
                end
                @subcommands.register(:add) do
                    Add
                end
                @subcommands.register(:remove) do
                    Remove
                end
            end

            def execute()
                options = {
                    env: []
                }

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin machine <subcommand> [name|id]"
                    option.separator ""
                    option.separator "Add and remove machines from the machine library"
                    option.separator ""
                    option.separator "Available subcommands:"
                    option.separator ""
                    @subcommands.each do |key, klass|
                        option.separator "     #{key.to_s.ljust(31)} #{klass.synopsis}"
                    end
                    option.separator ""
                    option.separator "For help with any individual subcommand run `minicoin machine <subcommand> -h"
                    option.separator ""
                end
                argv = parse_options(parser)
                return if !argv
                # argv will be [] but not nil if there's a subcommand

                command_class = @subcommands.get(@sub.to_sym) || @subcommands.get(@sub) if @sub
                return @env.ui.info(parser.help) if !command_class || !@sub
                command_class.new(@sub_args, @env).execute
            end
        end

        class List < Vagrant.plugin("2", :command)
            def self.synopsis
                "List machines available from the library"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin machine list"
                    option.separator ""
                    option.separator List::synopsis
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                end

                argv = parse_options(parser)
                unless !argv || argv = []
                    @env.ui.error "This command doesn't accept any parameters!"
                    @env.ui.error ""
                    @env.ui.info parser.help
                    return
                end

                ymlFiles = Dir['machines/**/*.yml']
                ymlFiles.each do |ymlFile|
                    machine = YAML.load_file(ymlFile)
                    puts "- #{machine["name"]}"
                end
            end
        end

        class Add < Vagrant.plugin("2", :command)
            def self.synopsis
                "Adds a machine from the library to minicoin"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin machine add [options] [name]"
                    option.separator ""
                    option.separator Add::synopsis
                    option.separator ""
                    option.on("--force", "Overwrite already installed machines from library") do
                        options[:force] = :true
                    end
                end

                argv = parse_options(parser)
                if !argv || argv == []
                    @env.ui.error "Machine name missing!"
                    @env.ui.error ""
                    @env.ui.info parser.help
                    return
                end

                installed_machines = []
                ::Minicoin.machines.each do |installed_machine|
                    installed_machines << installed_machine["name"]
                end
                ymlFiles = Dir['machines/**/*.yml']
                Dir.mkdir("#{$HOME}/minicoin/machines") unless Dir.exist?("#{$HOME}/minicoin/machines")
                argv.each do |machineName|
                    if installed_machines.include?(machineName) && !options[:force]
                        puts "#{machineName} already installed, set --force to overwrite"
                        next
                    end
                    found = false
                    ymlFiles.each do |ymlFile|
                        machineData = YAML.load_file(ymlFile)
                        if !machineData
                            @env.ui.error "Machine file #{ymlFile} cannot be loaded!"
                            next
                        end
                        if machineName == machineData["name"]
                            @env.ui.info "Adding machine file #{ymlFile} to the minicoin configuration in #{$HOME}/minicoin"
                            FileUtils.cp(ymlFile, "#{$HOME}/minicoin/#{ymlFile}")
                            if machineData["extends"]
                                args = ["machine", "add"]
                                args << "--force" if options[:force]
                                args << machineData["extends"]
                                @env.cli(*args)
                            end
                            found = true
                            break
                        end
                    end
                    if !found
                        @env.ui.error "Machine #{machineName} could not be found in the library!"
                    end
                end
            end
        end
        class Remove < Vagrant.plugin("2", :command)
            def self.synopsis
                "Removes a machine from the local minicoin configuration"
            end

            def initialize(argv, env)
                @env = env
                @argv = argv
            end

            def execute()
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin machine remove [name]"
                    option.separator ""
                    option.separator Remove::synopsis
                    option.separator ""
                end
                argv = parse_options(parser)
                if !argv || argv == []
                    @env.ui.error "Machine name missing!"
                    @env.ui.error ""
                    @env.ui.info parser.help
                    return
                end

                ymlFiles = Dir["#{$HOME}/minicoin/machines/**/*.yml"]
                argv.each do |machineName|
                    ymlFiles.each do |ymlFile|
                        machineData = YAML.load_file(ymlFile)
                        if machineData["name"] == machineName
                            @env.ui.info "Removing machine #{ymlFile} from the minicoin configuration in #{$HOME}/minicoin"
                            File.delete(ymlFile)
                        end
                    end
                end
            end
        end
    end
end
