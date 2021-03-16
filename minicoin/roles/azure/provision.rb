def azure_provision(box, name, args, machine)
    if !args.is_a?(Hash)
        raise "Argument error: expecting args to be a hash"
    end
    box.vm.provider :azure do |azure, override|
        args.each do |key, value|
            next if key == "role" or key == "role_path"
            eval("azure.#{key} = \"#{value}\"")
        end
    end
end
