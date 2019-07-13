def script_provision(vm, args)
    script = args["script"]
    if !script.is_a?(String)
        throw "Argument error: expecting a 'script' string"
    end
    vm.provision "shell", inline:args["script"]
end
