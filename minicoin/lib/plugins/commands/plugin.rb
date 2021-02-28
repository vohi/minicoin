module Minicoin
    module Commands
        class Plugin < Vagrant.plugin("2")
            name "Minicoin extensions"

            command(:list) do
                require_relative "list.rb"
                List
            end

            command(:describe, primary: false) do
                require_relative "describe.rb"
                Describe
            end

            command(:ls) do
                require_relative "ls.rb"
                LS
            end

            command(:cmd) do
                require_relative "cmd.rb"
                CMD
            end

            command(:install) do
                require_relative "install.rb"
                Install
            end

            command(:run) do
                require_relative "run.rb"
                Run
            end
        end
    end
end
