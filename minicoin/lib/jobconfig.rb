def jobconfig(machine)
    unless machine["jobconfigs"].nil?
        if ARGV[2] == "--index"
            jobconfig = machine["jobconfigs"][ARGV[3].to_i]
        else
            jobconfigs = []
            jobname = ARGV[1]
            configname = nil
            configname = ARGV[3] if ARGV[2] == "--config"
            index = -1
            machine["jobconfigs"].each do |jobconfig|
                index += 1
                next unless jobconfig["job"] == jobname
                next unless jobconfig["name"] == configname || configname.nil?
                jobconfigs << jobconfig
                jobconfig["_index"] = index
            end
            if jobconfigs.count > 1
                jobconfigs.each do |jobconfig|
                    print "#{jobconfig['_index']}) #{jobconfig['name']}\t"
                end
                jobconfig = {}
            else
                jobconfig = jobconfigs[0]
            end
        end
        unless jobconfig.nil?
            jobconfig.each do |key, value|
                next if key == "name" || key == "job" || key.start_with?("_")
                if value.is_a?(String)
                    value.gsub!("\\", "\\\\")
                    value.gsub!("\"", "\\\"")
                end
                
                puts "--#{key}"
                puts "\"#{value}\"" unless value.nil?
            end
        end
    end
end
