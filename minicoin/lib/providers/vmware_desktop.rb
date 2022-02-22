
def vmware_setup(box, machine)
    return unless Vagrant.has_plugin?("vagrant-vmware-desktop")
    box.vm.provider :vmware_desktop do |vmware|
        vmware.gui = machine["gui"] unless machine["gui"].nil?
        vmware.vmx["memsize"] = machine["memory"] unless machine["memory"].nil?
        vmware.vmx["numvcpus"] = machine["cpus"] unless machine["cpus"].nil?
        vmware.vmx["svga.vramSize"] = machine["vram"] unless machine["vram"].nil?
        vmware.vmx["vmx.allowNested"] = "TRUE"
        vmware.vmx["vhv.enable"] = "TRUE"
    end
end

def vmware_desktop_provision(box, name, args, machine)
    return if args.nil?
    raise "Argument error in vmware_desktop role: expecting args to be a hash" unless args.is_a?(Hash)
    box.vm.provider :vmware_desktop do |vmware|
        args.each do |key, value|
            vmware.vmx[key] = value
        end
    end
end
