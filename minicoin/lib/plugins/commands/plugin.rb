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

            command(:runinfo, primary: false) do
                require_relative "runinfo.rb"
                RunInfo
            end

            command(:jobconfig, primary: false) do
                require_relative "jobconfig.rb"
                JobConfig
            end
        end
    end
end
