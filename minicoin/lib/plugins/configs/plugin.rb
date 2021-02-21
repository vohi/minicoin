module Minicoin
    module MinicoinConfiguration
        class Plugin < Vagrant.plugin("2")
            name "Minicoin configuration extensions"

            config(:minicoin) do
                require_relative "minicoin.rb"
                Minicoin
            end
        end
    end
end
