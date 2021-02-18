module Minicoin
    class Describe < Vagrant.plugin("2", :command)
        def self.synopsis
            "prints the YAML for the machine after all merges"
        end

        def initialize(argv, env)
            super
        end

        def execute()
            parser = OptionParser.new do |option|
                option.banner = "Usage: minicoin describe [name|id]"
                option.separator ""
            end
            argv = parse_options(parser)
            return if !argv

            with_target_vms(argv) do |box|
                keys = box.config.instance_variable_get('@keys')
                minicoin = keys[:minicoin]
                machine = minicoin.machine
                machine.delete("_internal")
                puts machine.to_yaml
            end
        end
    end
end
