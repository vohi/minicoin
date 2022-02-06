def aws_provision(box, name, args, machine)
    raise "Argument error: aws provider configuration needs to be a hash" unless args.is_a?(Hash)
    box.vm.provider :aws do |aws, override|
        args.each do |key, value|
            case key
            when "role", "role_path"
            when "region_config"
                raise "Argument error: region_config needs to be a hash" unless value.is_a?(Array)
                value.each do |region_config|
                    raise "Argument error: each region_config needs to be a hash 'name => {...}'" unless region_config.is_a?(Hash)
                    region_config.each do |name, settings|
                        aws.region_config "#{name}" do |region|
                            if value.is_a?(Array) || value.is_a?(Hash)
                                eval("region.#{key} = #{value}")
                            else
                                eval("region.#{key} = \"#{value}\"")
                            end            
                        end
                    end
                end
            else
                if value.is_a?(Array) || value.is_a?(Hash)
                    eval("aws.#{key} = #{value}")
                else
                    eval("aws.#{key} = \"#{value}\"")
                end
            end
        end
    end
end
