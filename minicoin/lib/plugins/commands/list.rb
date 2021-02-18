module Minicoin
    class List < Vagrant.plugin("2", :command)
        def self.synopsis
            "lists all available machines"
        end

        def initialize(argv, env)
            super
        end

        def execute()
            parser = OptionParser.new do |option|
                option.banner = "Usage: minicoin list [name|id]"
                option.separator ""
            end
            argv = parse_options(parser)
            return if !argv
        end
    end
end
