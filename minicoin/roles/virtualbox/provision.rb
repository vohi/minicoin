def virtualbox_provision(box, name, args)
    if !args.is_a?(Hash)
        raise "Argument error: expecting args to be a hash"
    end
    box.vm.provider :virtualbox do |vb|
        args.each do |command, params|
            params.each do |key, value|
                vb.customize [
                    command, :id,
                    key, value
                ]
            end
        end
    end
end