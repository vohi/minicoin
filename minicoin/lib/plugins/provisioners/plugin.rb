module Minicoin
    module LocalCommandProvisioner
        class Plugin < Vagrant.plugin("2")
            name "local_command provisioner extension"

            config(:local_command, :provisioner) do
                require_relative "local_command.rb"
                Config
            end

            provisioner(:local_command) do
                require_relative "local_command.rb"
                Provisioner
            end
        end
    end
end
