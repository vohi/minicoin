def azure_provision(box, args)
    if !args.is_a?(Hash)
        raise "Argument error: expecting args to be a hash"
    end
    box.vm.provider :azure do |azure, override|
        args.each do |key, value|
            case key
            when "boxname"
            else
                eval("azure.#{key} = \"#{value}\"")
            end
        end
    end
end
