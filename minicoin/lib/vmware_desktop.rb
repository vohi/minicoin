
def vmware_setup(box, machine)
    box.vm.provider :vmware_desktop do |vmware|
        vmware.gui = machine["gui"] unless machine["gui"].nil?
        vmware.vmx["memsize"] = machine["memory"] unless machine["memory"].nil?
        vmware.vmx["numvcpus"] = machine["cpus"] unless machine["cpus"].nil?
        vmware.vmx["svga.vramSize"] = machine["vram"] unless machine["vram"].nil?
        vmware.vmx["vmx.allowNested"] = "TRUE"
        vmware.vmx["vhv.enable"] = "TRUE"
    end
end
