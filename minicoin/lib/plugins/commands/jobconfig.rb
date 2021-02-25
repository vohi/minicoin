module Minicoin
    module Commands
        class JobConfig < Vagrant.plugin("2", :command)
            def self.synopsis
                "prints the configuration for jobs"
            end

            def execute()
                require_relative "run.rb"
                options = {}

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin runinfo [vm-name]"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""

                    option.on("-j JOB", "--job JOB", "The job") do |o|
                        options[:jobname] = o
                    end
                    option.on("-c CONFIGNAME", "--config CONFIGNAME", "The name of the configuration") do |o|
                        options[:jobconfig] = o
                    end
                    option.on("-i INDEX", "--index INDEX", "The index of the configuration") do |o|
                        begin
                            options[:jobconfig_index] = Integer(o)
                        rescue Exception => e
                            @env.ui.error e
                        end
                    end
                end
                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv, { :single_target => true }) do |box|
                    keys = box.config.instance_variable_get('@keys')
                    minicoin = keys[:minicoin]
                    machine = minicoin.machine

                    job = Minicoin::Commands::Job.new(options, argv, @env)
                    jobconfig = job.jobconfig(options, box)
                    options = jobconfig["options"] || []
                    options.each do |key, value|
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
