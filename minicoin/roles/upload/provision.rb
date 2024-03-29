def upload_provision(box, name, role_params, machine)
  files = role_params["files"]
  raise "Argument error: expecting a 'files' hash table from source to destination" unless files.is_a?(Hash)
  files.each do |source, destination|
    source = source.gsub("~", $HOME)
    if box.vm.guest == :windows
      destination = destination.gsub("~/", "C:\\\\Users\\\\vagrant\\\\")
    else
      destination = destination.gsub("~/", "")
    end

    box.vm.provision "upload:#{source}",
      type: :file,
      source: source,
      destination: destination
  end
end
