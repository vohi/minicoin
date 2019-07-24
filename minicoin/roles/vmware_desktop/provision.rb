def vmware_fusion_provision(box, args)
    if !args.is_a?(Hash)
        throw "Argument error: expecting args to be a hash"
    end
    box.vm.provider :vmware_desktop do |vmware|
        args.each do |key, value|
            vmware.vmx[key] = value
        end
    end
end