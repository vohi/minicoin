require 'open3'

module LocalCommand
    class Config < Vagrant.plugin("2", :config)
        attr_accessor :command
        attr_accessor :commands
    end

    class Plugin < Vagrant.plugin("2")
        name "local_command"

        config(:local_command, :provisioner) do
            Config
        end

        provisioner(:local_command) do
            Provisioner
        end
    end

    class Provisioner < Vagrant.plugin("2", :provisioner)
        def provision
            commands = config.commands
            if commands.nil?
                if config.command.is_a?(Array)
                    commands = config.command
                else
                    commands = [config.command]
                end
            end
            commands.each do |command|
                stdout, stderr, status = Open3.capture3(command)
                throw stderr if status != 0
            end
        end
    end
end
