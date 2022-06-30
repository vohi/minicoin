module Minicoin
    module Commands
        class List < Vagrant.plugin("2", :command)
            def self.synopsis
                "lists all available machines"
            end

            def execute()
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin list [name|id]"
                    option.separator ""
                    option.separator "Options:"
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
                    output_options = { :target => name }
                    if machine[:disabled]
                        output_options[:color] = :yellow
                        indicator = "X"
                        provider = "not available: #{machine[:disabled]}"
                    elsif active_entry
                        output_options[:color] = :green
                        indicator = "*"
                        provider = active_entry[1].to_s
                    end
                    if @env.ui.is_a?(Vagrant::UI::MachineReadable)
                        @env.ui.machine("box-name", machine_box, **output_options)
                        @env.ui.machine("provider-name", provider.to_s, **output_options) if active_entry
                        @env.ui.machine("state", indicator, **output_options)
                    else
                        provider = " (#{provider})" if provider
                        machine_box ||= "[not set]"
                        @env.ui.output "#{indicator || " "} #{(name).ljust(25)} #{(machine_box + provider.to_s).ljust(25)}", **output_options
                    end
                end
            end
        end
    end
end
