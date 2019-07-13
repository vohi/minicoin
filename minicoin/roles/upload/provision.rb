def upload_provision(vm, role_params)
  files = role_params["files"]
  if !files.is_a?(Hash)
    throw "Argument error: expecting a 'files' hash table from source to desintation"
  end
  files.each do |source, destination|
    vm.provision "file", source: source, destination: destination
  end
end
