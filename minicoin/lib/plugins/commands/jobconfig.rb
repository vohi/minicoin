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

            with_target_vms(argv) do |box|
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
                    # print either the configuration, or the tab-separated list of matches
                    if jobconfigs.count == 0
                        @logger.debug("No matching configurations found for job '#{@job}'")
                    elsif jobconfigs.count == 1
                        jobconfig = jobconfigs.first
                        jobconfig.each do |key, value|
                            next if key == "name" || key == "job" || key.start_with?("_")
                            if value.is_a?(String)
                                value.gsub!("\\", "\\\\")
                                value.gsub!("\"", "\\\"")
                            end
                            
                            puts "--#{key}"
                            puts "\"#{value}\"" unless value.nil?
                        end
                    else
                        jobconfigs.each do |jobconfig|
                            print "#{jobconfig['_index']}) #{jobconfig['name']}"
                            print " - #{jobconfig['description']} " unless jobconfig['description'].nil?
                            print "\t"
                        end
                    end
                end
            end
        end
    end
end
