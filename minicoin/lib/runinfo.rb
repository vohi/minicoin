def runinfo(machine, box)
    name = machine["name"]
    project_dir = ENV["MINICOIN_PROJECT_DIR"]
    guest_dir = nil
    # check whether we are in a subdirectory of a mapped path, and use the best match
    (machine["fs_mappings"] || {}).each do |hostpath, guestpath|
        hostpath = hostpath.gsub("~", "$HOME")
        hostpath = expand_env(hostpath, nil)
        match_length = -1
        if project_dir.start_with?(hostpath) && hostpath.length > match_length
            match_length = hostpath.count('/') unless hostpath == ENV["HOME_SHARE"]
            guest_dir = project_dir.dup #[hostpath.length, -1]
            guest_dir[hostpath] = guestpath
        end
    end
    if guest_dir.nil? || guest_dir.empty?
        STDERR.puts "==> #{name}: the host path '#{project_dir}' doesn't map to any location on the guest:"
        (machine["fs_mappings"] || {}).each do |hostpath, guestpath|
            STDERR.puts "    #{hostpath} => #{guestpath}"
        end
        guest_dir = project_dir
    end
    puts "#{name} #{machine['os']} #{box.vm.communicator} #{ENV['GUEST_HOMES']} #{ENV["USER"]} #{ENV["HOME_SHARE"]} #{guest_dir}"
end
