module Minicoin
    class JobConfig < Vagrant.plugin("2", :command)
        def self.synopsis
            "prints the configuration for jobs"
        end

        def initialize(argv, env)
            super
            @job = nil
            @configname = nil
            @index = nil
        end
        def execute()
            opts = OptionParser.new do |option|
                option.banner = "Usage: minicoin runinfo [vm-name]"
                option.separator ""

                option.on("-j JOB", "--job JOB", "The job") do |job|
                    @job = job
                end
                option.on("-c CONFIGNAME", "--config CONFIGNAME", "The name of the configuration") do |configname|
                    @configname = configname
                end
                option.on("-i INDEX", "--index INDEX", "The index of the configuration") do |index|
                    @index = index.to_i
                end
            end
            argv = parse_options(opts)
            return if !argv

            with_target_vms(argv, { :single_target => true }) do |box|
                keys = box.config.instance_variable_get('@keys')
                minicoin = keys[:minicoin]
                machine = minicoin.machine

                unless machine["jobconfigs"].nil?
                    # enumerate all jobconfigs
                    jobconfigs = []
                    machine["jobconfigs"].each do |jobconfig|
                        jobconfig["_index"] = jobconfigs.length
                        jobconfigs << jobconfig
                    end
                    # find the ones that match
                    jobconfigs = jobconfigs.select do |jobconfig|
                        res = true
                        res = jobconfig["job"] == @job unless @job.nil?
                        res = res && jobconfig["name"] == @configname unless @configname.nil?
                        res = res && jobconfig["_index"] == @index unless @index.nil?
                        res
                    end
                    @logger.debug("#{jobconfigs.count} matching configurations found for job '#{@job}'")
                    # print either the configuration, or the tab-separated list of matches
                    if jobconfigs.count == 0
                        jobconfig = {}
                    elsif jobconfigs.count > 1
                        if @env.ui.is_a?(Vagrant::UI::MachineReadable) || @env.ui.is_a?(Vagrant::UI::NonInteractive)
                            raise Vagrant::Errors::UIExpectsTTY
                        end
                        ui_channel = { :channel => :error }
                        @env.ui.output "Multiple job configurations are available:", ui_channel
                        @env.ui.output "", ui_channel
                        jobconfigs.each do |jobconfig|
                            line = "#{jobconfig['_index']}) #{jobconfig['name']}"
                            line += " - #{jobconfig['description']} " unless jobconfig['description'].nil?
                            @env.ui.output line, ui_channel
                        end
                        @env.ui.output "", ui_channel
                        jobconfig = nil
                        while !jobconfig
                            if @env.ui.stdin.tty?
                                selection = @env.ui.ask "Selection: ", ui_channel
                            else
                                @env.ui.output "Selection: ", ui_channel
                                selection = @env.ui.stdin.gets.chomp
                            end
                            filtered = jobconfigs.select do |jc|
                                jc["_index"].to_s == selection
                            end
                            jobconfig = filtered.first if filtered.count == 1
                            # no point in asking again if the input was piped
                            raise Vagrant::Errors::UIExpectsTTY if !jobconfig && !@env.ui.stdin.tty?
                        end
                        @env.ui.output "Selected: '#{jobconfig['name']}' (run job '#{jobconfig['job']}' with --jobconfig #{jobconfig['name']} to skip this dialog)\n", ui_channel
                    else
                        jobconfig = jobconfigs.first
                    end
                    jobconfig.each do |key, value|
                        next if key == "name" || key == "job" || key == "description" || key.start_with?("_")
                        if value.is_a?(String)
                            value.gsub!("\\", "\\\\")
                            value.gsub!("\"", "\\\"")
                        end

                        puts "--#{key}"
                        value = value.join(",") if value.is_a?(Array)
                        if value
                            value = "\"#{value}\"" if value.include?(" ")
                            puts value
                        end
                    end
                end
            end
        end
    end
end
