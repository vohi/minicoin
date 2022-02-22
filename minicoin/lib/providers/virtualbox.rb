# VirtualBox specific settings
def virtualbox_setup(box, machine)
    box.vm.provider :virtualbox do |vb|
        vb.memory = machine["memory"] unless machine["memory"].nil?
        vb.cpus = machine["cpus"] unless machine["cpus"].nil?
        vb.gui = machine["gui"] unless machine["gui"].nil?
        vb.customize ["modifyvm", :id, "--vram", machine["vram"]] unless machine["vram"].nil?
        vb.customize ["modifyvm", :id, "--monitorcount", machine["screens"]] unless machine["screens"].nil?
        
        vb.name = machine["name"]
        
        modifyvm = {}
        modifyvm["--clipboard"] = "bidirectional"
        modifyvm["--vram"] = machine["vram"] unless machine["vram"].nil?
        modifyvm["--nictype1"] = machine["nictype1"] unless machine["nictype1"].nil?
        modifyvm["--nictype2"] = machine["nictype2"] unless machine["nictype2"].nil?
        modifyvm["--vrde"] = "on" if machine["rdp"]
        modifyvm["--vrdeport"] = "5000-5050" if machine["rdp"]
        modifyvm["--graphicscontroller"] = "vmsvga" unless box.vm.guest == :windows
        modifyvm["--graphicscontroller"] = "vboxsvga" if box.vm.guest == :windows
        
        extradata = {}
        
        if !machine["resolution"].nil?
            resolution_map = {
                "VGA" => "640x480",
                "SVGA" => "800x600",
                "XGA" => "1024x768",
                "XGA+" => "1152x864",
                "HD" => "1280x720",
                "WXGA" => "1280x800",
                "SXGA" => "1280x1024",
                "SXGA+" => "1400x1050",
                "WXGA+" => "1440x900",
                "HD+" => "1600x900",
                "UXGA" => "1600x1200",
                "WSXGA+" => "1680x1050",
                "Full HD" => "1920x1080",
                "WUXGA" => "1920x1200",
                "DCI 2K" => "2048x1080",
                "Full HD+" => "2160x1440",
                "2304x1440" => "2304x1440", # unnamed
                "QHD" => "2560x1440",
                "WQXGA" => "2560x1600",
                "QWXGA+" => "2880x1800",
                "QHD+" => "3200x1800",
                "WQSXGA" => "3200x2048",
                "4K UHD" => "3840x2160",
                "WQUXGA" => "3840x2400",
                "DCI 4K" => "4096x2160",
                "HXGA" => "4096x3072",
                "UHD+" => "5120x2880",
                "WHXGA" => "5120x3200",
                "WHSXGA" => "6400x4096",
                "HUXGA" => "6400x4800",
                "8K UHD2" => "7680x4320"
            }
            res_name = machine["resolution"]
            resolution = resolution_map[res_name];
            if resolution.nil?
                puts "==> #{name}: Using custom display resolution #{res_name}"
                resolution = res_name;
            end
            extradata["CustomVideoMode1"] = "#{resolution}x32"
            extradata["VBoxInternal2/EfiGraphicsResolution"] = "#{resolution}"
        end
        extradata["GUI/ScaleFactor"] = machine["guiscale"] unless machine["guiscale"].nil?
        
        modifyvm.each do |key, value|
            vb.customize [
                "modifyvm", :id,
                key, value
            ]
        end
        extradata.each do |key, value|
            vb.customize [
                "setextradata", :id,
                key, value
            ]
        end
    end

    # if it's a virtualbox VM, workaround destroy bug in VirtualBox
    vboxdir = "#{$HOME}/VirtualBox VMs/#{machine['name']}"
    if File.directory?(vboxdir)
        box.trigger.after :destroy do |trigger|
            trigger.name = "Workaround for VirtualBox bug"
            trigger.ruby do |env, machine|
                if File.directory?(vboxdir)
                    STDERR.puts "#{vboxdir} still exists, deleting!"
                    require 'fileutils'
                    FileUtils.remove_dir(vboxdir, true)
                end
            end
        end
    end
end

def virtualbox_provision(box, name, args, machine)
    return if args.nil?
    raise "Argument error in virtualbox role: expecting args to be a hash" unless args.is_a?(Hash)
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
