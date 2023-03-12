module Minicoin
    module Metal
        class Plugin < Vagrant.plugin("2")
            name "Metal provider"
            provider(:metal) do
                require_relative "provider.rb"
                Provider
            end
        end
    end
end
