def virtualbox_provision(box, name, args, machine)
    if !args.is_a?(Hash)
        raise "Argument error in virtualbox role: expecting args to be a hash"
    end
    box.vm.provider :virtualbox do |vb|
        args.each do |command, params|
            if !params.is_a?(Hash)
                raise "Argument error in virtualbox role: parameters for '#{command}' must be a hash"
            end
            if params.is_a?(Hash)
                params.each do |key, value|
                    vb.customize [
                        command, :id,
                        key, *value
                    ]
                end
            end
        end
    end
end
