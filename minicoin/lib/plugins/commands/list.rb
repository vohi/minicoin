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

            active_machines = @env.active_machines || []
            unless @env.ui.is_a?(Vagrant::UI::MachineReadable)
                @env.ui.output "Available machines are:"
                @env.ui.output ""
            end
            ::Minicoin.machines.each do |machine|
                next if ::Minicoin.skip?(machine)
                name = machine["name"]
                machine_box = machine["box"]
                active_entry = active_machines.select do |machine|
                    machine[0].to_s == name
                end
                if active_entry.count > 1 # there should only be one match
                    @logger.warn "Too many matches for #{name}"
                end
                active_entry = active_entry.first
                indicator = nil
                provider = nil
                if active_entry
                    indicator = "*"
                    provider = active_entry[1].to_s
                end
                if @env.ui.is_a?(Vagrant::UI::MachineReadable)
                    @env.ui.output indicator.to_s,name, machine_box, provider, { :target => self.class }
                else
                    provider = " (#{provider})" if provider
                    @env.ui.output "#{indicator || " "} #{(name).ljust(25)} #{(machine_box + provider.to_s).ljust(25)}"
                end
            end
        end
    end
end
