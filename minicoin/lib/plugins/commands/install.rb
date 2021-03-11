module Minicoin
    module Commands
        class Install < Vagrant.plugin("2", :command)
            def self.synopsis
                "Installs software packages on the guest"
            end

            def execute()
                options = {}

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin install [options] [name|id] -- extra install options"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                    option.on("--package PACKAGE", "-p PACKAGE", "The package(s) to install on the guest") do |o|
                        options[:packages] = o
                    end
                    option.on("-- extra install options", "Arguments pass through to the package manager")
                end

                # everything after the "--" goes to choco/apt/zypper etc
                split_index = @argv.index("--")
                if split_index
                    options[:args] = @argv.drop(split_index + 1)
                    @argv = @argv.take(split_index)
                end

                argv = parse_options(parser)
                return if !argv
                raise Minicoin::Errors::MissingArgument.new("no package specified") if options[:packages].nil?

                with_target_vms(argv) do |vm|
                    unless vm.communicate.ready?
                        vm.ui.error "Machine not ready"
                        next
                    end
                    vm.ui.info "Installing '#{options[:packages]}'"
                    vm.communicate.upload("./roles/install", ".minicoin/roles")
                    if vm.guest.name == :windows
                        optionflags = "-Options @(\"#{options[:args].join('","')}\")" if options[:args]
                        begin
                            vm.communicate.execute(".minicoin\\roles\\install\\provision.ps1 -Packages #{options[:packages].gsub(' ',',')} #{optionflags}") do |type, data|
                                echo(vm.ui, type, data.rstrip)
                            end
                        rescue
                            vm.ui.error "Error installing packages '#{options[:packages]}' with options #{options[:args]}"
                            raise Vagrant::Errors::VagrantInterrupt.new
                        end
                        vm.communicate.sudo("Remove-Item .minicoin\\roles\\install -Force -Recurse")
                    else
                        optionflags = "--options '#{options[:args].join(" ")}'" if options[:args]
                        begin
                            vm.communicate.sudo("chmod -R +x .minicoin; .minicoin/roles/install/provision.sh --packages \"#{options[:packages]}\" #{optionflags}") do |type, data|
                                echo(vm.ui, type, data.chomp)
                            end
                        rescue
                            vm.ui.error "Error installing package(s) '#{options[:packages]}' with options #{options[:args]}"
                            raise Vagrant::Errors::VagrantInterrupt.new
                        end
                        vm.ui.info "Cleaning up"
                        vm.communicate.sudo("rm -rf .minicoin/roles/install")
                    end
                end
            end

            private

            def echo(ui, type, data)
                if type == :stderr
                    ui.error data
                else
                    ui.detail data
                end
            end
        end
    end
end
