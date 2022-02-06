def vmware_desktop_provision(box, name, args, machine)
    if !args.is_a?(Hash)
        raise "Argument error in vmware_desktop role: expecting args to be a hash"
    end
    box.vm.provider :vmware_desktop do |vmware|
        args.each do |key, value|
            vmware.vmx[key] = value
        end
    end
end
