module Minicoin
    class Plugin < Vagrant.plugin("2")
        name "Minicoin extensions"

        config(:minicoin) do
            require_relative "plugins/configs/minicoin.rb"
            Minicoin
        end

        config(:local_command, :provisioner) do
            require_relative "plugins/provisioners/local_command.rb"
            LocalCommand::Config
        end

        provisioner(:local_command) do
            require_relative "plugins/provisioners/local_command.rb"
            LocalCommand::Provisioner
        end

        command(:list) do
            require_relative "plugins/commands/list.rb"
            List
        end

        command(:describe, primary: false) do
            require_relative "plugins/commands/describe.rb"
            Describe
        end

        command(:runinfo, primary: false) do
            require_relative "plugins/commands/runinfo.rb"
            RunInfo
        end

        command(:jobconfig, primary: false) do
            require_relative "plugins/commands/jobconfig.rb"
            JobConfig
        end
    end
end
