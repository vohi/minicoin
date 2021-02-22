module Minicoin
    module Commands
        class CMD < Vagrant.plugin("2", :command)
            def self.synopsis
                "Run a command on the guest"
            end

            def execute()
                options = {}

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin cmd [options] [name|id] -- command"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                    option.on("-- command", "The command to execute on the guest")
                end

                # everything after the "--" goes to ssh/winrm
                split_index = @argv.index("--")
                if split_index
                    command = @argv.drop(split_index + 1).join(" ")
                    @argv = @argv.take(split_index)
                end

                argv = parse_options(parser)
                return if !argv
                
                if command.nil? || command.empty?
                    @env.ui.error "No command provided"
                    return
                end

                with_target_vms(argv) do |vm|
                    unless vm.communicate.ready?
                        vm.ui.error "Machine not ready"
                        next
                    end
                    vm.ui.info "Running '#{command}'"
                    if vm.guest.name == :windows
                        vm.communicate.execute("cd \$Env:USERPROFILE; #{command}") do |type, data|
                            echo(vm.ui, type, data.rstrip)
                        end
                    else
                        vm.communicate.execute(command) do |type, data|
                            echo(vm.ui, type, data.chomp)
                        end
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
