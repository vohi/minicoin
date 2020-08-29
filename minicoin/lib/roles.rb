def fetch_file(uri, local)
    begin
        downloader = Vagrant::Util::Downloader.new(uri, local)
        downloader.download!
    rescue => error
        puts "Error downloading #{uri}: #{error}"
        return false
    end
end

def insert_disk(box, disk_filename, role_params)
    disk_data = YAML.load_file(disk_filename)
    disk_file = disk_data["file"]
    disk_archive = disk_data["archive"]
    disk_urls = disk_data["urls"]
    if disk_urls.is_a?(String)
        disk_urls = [disk_urls]
    end
    disk_urls = [] if disk_urls.nil?
    disk_urls += $urls["disks"] unless $urls["disks"].nil?
    
    if disk_archive.nil?
        disk_archive = disk_file
    end
    
    disk_cache = "#{$PWD}/.diskcache"
    if ["up", "provision", "reload"].include? ARGV[0]
        Dir.mkdir(disk_cache) unless Dir.exist?(disk_cache)
        
        if !File.file?("#{disk_cache}/#{disk_file}")
            if !File.file?("#{disk_cache}/#{disk_archive}")
                disk_urls.each do |server|
                    url = URI("#{server}/disks/#{disk_archive}")
                    puts "Downloading '#{url}'..."
                    if fetch_file(url, "#{disk_cache}/#{disk_archive}")
                        break
                    end
                end
            end
            if !File.file?("#{disk_cache}/#{disk_archive}")
                puts "Failed to download '#{disk_archive}' from any of #{disk_urls}"
            else
                puts "Extracting '#{disk_archive}'"
                begin
                    require 'zip'
                    Zip::File.open("#{disk_cache}/#{disk_archive}") do |zipfile|
                        zipfile.extract("#{disk_file}", "#{disk_cache}/#{disk_file}")
                    end
                end
            end
        end
        if !File.file?("#{disk_cache}/#{disk_file}")
            puts "==> Disk file '#{disk_file}' not available"
            return false
        end
        
        disk_settings = disk_data["settings"] unless disk_data.nil?
        if disk_settings.nil?
            disk_settings = {}
        end
        # default settings, disks can override
        disk_settings["storagectl"] = "SATA" unless !disk_settings["storagectl"].nil?
        
        if disk_file.end_with?(".iso")
            disk_settings["port"] = "1" unless !disk_settings["port"].nil?
            disk_settings["type"] = "dvddrive" unless !disk_settings["type"].nil?
        elsif disk_file.end_with?(".vdi") || disk_file.end_with?(".vmdk")
            disk_settings["port"] = "2" unless !disk_settings["port"].nil?
            disk_settings["type"] = "hdd" unless !disk_settings["type"].nil?
            disk_settings["mtype"] = "multiattach" unless !disk_settings["mtype"].nil?
        end
        
        # boxes can override disk settings
        if role_params.is_a?(Hash)
            role_params.each do |key, value|
                disk_settings[key] = value
            end
        end
        
        box.vm.provider :virtualbox do |vb|
            storage_params = [
                "storageattach", :id,
                "--medium", "#{disk_cache}/#{disk_file}",
            ]
            
            disk_settings.each do |key, value|
                storage_params += ["--#{key}", "#{value}"]
            end
            vb.customize storage_params
        end
        box.vm.provider :vmware_desktop do |vmware|
            # map defaults to VMWare
            device_ctl = "sata0:" if disk_settings["storagectl"] == "SATA"
            device_ctl = "ide0:" if disk_settings["storagectrl"] == "IDE"
            device_port = disk_settings["port"]
            
            device_string = "#{device_ctl}#{device_port}"
            if disk_settings["type"] == "dvddrive"
                device_type = "cdrom-image"
            elsif disk_settings["type"] == "hdd"
                device_type = "disk"
            end
            
            vmware.vmx["#{device_string}.present"] = "TRUE"
            vmware.vmx["#{device_string}.deviceType"] = device_type
            vmware.vmx["#{device_string}.filename"] = "#{disk_cache}/#{disk_file}"
            vmware.vmx["#{device_string}.startConnected"] = "TRUE"
        end
    end
    return true
end

def read_process(cmd, ui)
    Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
        begin
            while true do
                ready = IO.select([stdout, stderr], nil, nil, 0)
                unless ready.nil?
                    ready[0].each do |io|
                        line = io.read_nonblock(256)
                        ui.success(line.chomp) if io == stdout
                        ui.error(line.chomp) if io == stderr
                    end
                end
                IO.select([stdout, stderr])
            end
        rescue EOFError
            # EOF, process finished
        end
        if thread.value != 0
            raise "Error (#{thread.value}) from process"
        end
    end
end

## Add role as provisioning step for box
def add_role(box, role, name)
    if !role.is_a?(Hash)
        role = { "role" => role }
    end
    role_params = role
    role, role_name = role.shift
    if role == "role"
        role = role_name
    elsif role_name != nil
        role_params[role] = role_name
    end
    
    role_params["boxname"] = name
    role_params.each do |key, value|
        if value.nil?
            next
        end
        if value.is_a?(String)
            new_value = expand_env(value, box)
            if new_value.nil?
                puts "==> #{name}: Unexpanded environment variable in '#{value}' - skipping role '#{role}'"
                return
            end
            role_params[key] = new_value
        elsif value.is_a?(Array)
            array = []
            value.each do |entry|
                new_entry = expand_env(entry, box)
                if new_entry.nil?
                    puts "==> #{name}: Unexpanded environment variable in '#{entry}' - skipping role '#{role}'"
                    return
                end
                array << new_entry
            end
            role_params[key] = array
        elsif value.is_a?(Hash)
            new_hash = {}
            value.each do |k, v|
                # left side of key/value pair refers to the host
                new_key = expand_env(k, nil)
                new_value = expand_env(v, box)
                if new_key.nil? || new_value.nil?
                    puts "==> #{name}: Unexpanded environment variable in '#{value}' - skipping role '#{role}'"
                    return
                end
                new_hash[new_key] = new_value
            end
            role_params[key] = new_hash
        end
    end
    
    # user can add or override roles
    role_path = File.join($HOME, "minicoin/roles/#{role}")
    if !File.exist?(role_path)
        role_path = "#{$PWD}/roles/#{role}"
    end
    activity = false

    # check for pre--provisioning script to run locally
    if File.file?("#{role_path}/pre-provision.sh")
        pre_provision = lambda do |machine|
            read_process("#{role_path}/pre-provision.sh #{name}", machine.ui)
        end
        box.vm.provision "Pre-provisiong for #{role}",
            type: :local_command,
            code: pre_provision
    end

    if File.file?("#{role_path}/playbook.yml")
        box.vm.provision "ansible" do |ansible|
            ansible.playbook = "#{role_path}/playbook.yml"
            ansible.become = true unless box.vm.guest == :windows
        end
        activity = true
    elsif File.file?("#{role_path}/disk.yml")
        if ["up", "provision", "reload", "validate"].include? ARGV[0]
            activity = true
            if !insert_disk(box, "#{role_path}/disk.yml", role_params)
                puts "==> #{name}: Attaching disk failed for role '#{role}'"
            end
        end
    elsif File.file?("#{role_path}/Dockerfile")
        docker_args = "--rm"
        role_params.each do |param, value|
            if value.nil?
                docker_args += " --#{param}"
            elsif value.is_a?(Array)
                value.each do |entry|
                    docker_args += " --#{param} \"#{entry}\""
                end
            else
                docker_args += " --#{param} \"#{value}\""
            end
        end
        box.vm.provision "file",
            source: "#{role_path}/Dockerfile",
            destination: "#{role}/Dockerfile"
        box.vm.provision "docker" do |docker|
            docker.build_image "#{role}", args: docker_args
        end
        activity = true
    end
    
    # always check for a provisioning extension
    provisioning_file = "#{role_path}/provision.rb"
    if File.file?(provisioning_file)
        require provisioning_file
        begin
            eval("#{role}_provision(box, role_params)")
            activity = true
        rescue => error
            puts "==> #{name}: Error with #{role} role: #{error}"
        end
    end
    
    # always check for a provisioning script
    script_ext = ".sh"
    arg_marker = "--"
    combine_array = false
    script_args = [role, name, $USER]
    upload_path = "/tmp/vagrant-shell/"
    if box.vm.guest == :windows
        script_ext = ".cmd"
        if File.file?("#{role_path}/provision.ps1")
            script_ext = ".ps1"
            arg_marker = "-"
            combine_array = true
            script_args = ["-role", role, "-user", $USER]
        end
        upload_path = "c:\\Windows\\temp\\"
    end
    upload_path += "provision_#{role}#{script_ext}"
    provisioning_file = "#{role_path}/provision#{script_ext}"
    if File.file?(provisioning_file)
        activity = true
        if role_params.is_a?(Hash)
            role_params.each do |key, param|
                array=param
                if !param.is_a?(Array)
                    array=[]
                    array << param
                end
                if combine_array
                    script_args << "#{arg_marker}#{key}"
                    script_args << array.join(",")
                else
                    array.each do |value|
                        script_args << "#{arg_marker}#{key}" unless combine_array
                        if value.is_a?(Hash)
                            value = value.to_json;
                        end
                        script_args << "#{value}" unless value.nil?
                    end
                end
            end
        end
        box.vm.provision "shell", name: "#{role}", path: "#{provisioning_file}",
            args: script_args,
            upload_path: upload_path,
            privileged: true
    end
    
    # check for post--provisioning script to run locally
    if File.file?("#{role_path}/post-provision.sh")
        post_provision = lambda do |machine|
            read_process("#{role_path}/post-provision.sh #{name}", machine.ui)
        end
        box.vm.provision "Post-provisiong for #{role}",
            type: :local_command,
            code: post_provision
    end
    if ! activity
        puts "==> #{name}: Provisioning script for role #{role} at '#{provisioning_file}' not found!"
    end
end
