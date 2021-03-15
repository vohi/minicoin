module Minicoin
    module Commands
        class CMD < Vagrant.plugin("2", :command)
            def self.synopsis
                "Run a command on the guest"
            end

            def execute()
                options = {
                    env: []
                }

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin cmd [options] [name|id] -- command"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                    option.on("--privileged", "Run command with elevated privileges") do |o|
                        options[:privileged] = o
                    end
                    option.on("--quiet", "Suppress all output") do |o|
                        options[:quiet] = o
                    end
                    option.on("--powershell", "Run the command in powershell on Windows guests") do |o|
                        options[:powershell] = o
                    end
                    option.on("--env ENV=VAL", "Specify comma-separated list of environment variables") do |o|
                        options[:env] += o.split(",")
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
                raise Minicoin::Errors::MissingArgument.new("No command provided") if command.nil? || command.empty?

                exit_code = 0
                with_target_vms(argv) do |vm|
                    ui = argv.count > 1 ? vm.ui : @env.ui
                    unless vm.communicate.ready?
                        vm.ui.error "Machine not ready"
                        next
                    end
                    vm.ui.info "Running '#{command}'" unless options[:quiet]
                    opts = {}.tap do |o|
                        o[:error_check] = false
                    end
                    if vm.guest.name == :windows
                        # even though the WinRM communicator has a :shell option, we always go through
                        # powershell, as otherwise we lose the exit code. Downside is that we get the
                        # un-catchable "NativeCommandError" for the first line of output to stderr.
                        opts[:elevated] = true if options[:privileged]
                        do_command = "cd $Env:USERPROFILE\n"
                        options[:env].each do |env|
                            md = /([A-Za-z0-9]+[\+]?)=(.*)/.match(env)
                            key = md[1]
                            value = md[2]
                            if key.end_with?('+')
                                key = key[0..-2]
                                do_command += "Set-Item -Path Env:#{key} -Value (\"#{value};\" + $Env:#{key})"
                            else
                                do_command += "Set-Item -Path Env:#{key} -Value \"#{value}\""
                            end
                            do_command += "\n"
                        end
                        do_command += options[:powershell] ? command : "& cmd /C \"#{command}\""
                    else
                        opts[:sudo] = true if options[:privileged]
                        do_command = ""
                        options[:env].each do |env|
                            md = /([A-Za-z0-9]+[\+]?)=(.*)/.match(env)
                            key = md[1]
                            value = md[2]
                            if key.end_with?('+')
                                key = key[0..-2]
                                value="#{value}:$#{key}"
                            end
                            do_command += "#{key}=\"#{value}\";"
                        end
                        do_command += command
                    end
                    vm_exit_code = vm.communicate.execute(do_command, opts) do |type, data|
                        next if options[:quiet]
                        data.rstrip!
                        next if data.nil?
                        if type == :stderr
                            ui.error data
                        else
                            ui.detail data
                        end        
                    end
                    unless options[:quiet]
                        if vm_exit_code == 0
                            vm.ui.success "'#{command}' finished with #{vm_exit_code}"
                        else
                            vm.ui.error "'#{command}' finished with #{vm_exit_code}"
                        end
                    end
                    exit_code += vm_exit_code
                end
                exit_code
            end
        end
    end
end
