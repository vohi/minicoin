def script_provision(box, args)
    script = args["script"]
    if !script.is_a?(String)
        throw "Argument error: expecting a 'script' string"
    end
    upload_path = "/tmp/vagrant-shell/script_provisioning.sh"
    if box.vm.guest == :windows
        upload_path = "c:\\Windows\\temp\\script_provisioning.ps1"
    end
    box.vm.provision "shell",
      name: "script_provisioning",
      upload_path: upload_path,
      inline:args["script"]
end
