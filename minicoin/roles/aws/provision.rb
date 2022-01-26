def aws_provision(box, name, args, machine)
    if !args.is_a?(Hash)
        raise "Argument error: expecting args to be a hash"
    end
    box.vm.provider :aws do |aws, override|
        args.each do |key, value|
            next if key == "role" or key == "role_path"
            if value.is_a?(Array) || value.is_a?(Hash)
                eval("aws.#{key} = #{value}")
            else
                eval("aws.#{key} = \"#{value}\"")
            end
        end
    end
end
