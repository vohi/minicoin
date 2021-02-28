module Minicoin
    module Commands
        class Describe < Vagrant.plugin("2", :command)
            def self.synopsis
                "prints the YAML for the machine after all merges"
            end

            def execute()
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin describe [name|id]"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                end
                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |box|
                    minicoin = Minicoin.get_config(box)
                    puts minicoin.to_hash.to_yaml
                end
            end
        end
    end
end
