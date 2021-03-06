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
                    option.on("--quiet", "Suppress all output") do |o|
                        options[:quiet] = o
                    end
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

                exit_code = 0
                with_target_vms(argv) do |vm|
                    unless vm.communicate.ready?
                        vm.ui.error "Machine not ready"
                        next
                    end
                    vm.ui.info "Running '#{command}'"
                    opts = {}
                    opts = {error_check: false} if options[:quiet]
                    command = "cd \$Env:USERPROFILE; #{command}" if vm.guest.name == :windows
                    exit_code = vm.communicate.execute(command, opts) do |type, data|
                        echo(vm.ui, type, data.rstrip.chomp) unless options[:quiet]
                    end
                end
                vm.ui.status "#{command} finished with #{exit_code}"
                exit_code
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
