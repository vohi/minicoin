def script_provision(box, args)
    script = args["script"]
    if !script.is_a?(String)
        raise "Argument error: expecting a 'script' string"
    end
    upload_path = "/tmp/vagrant-shell/script_provisioning.sh"
    if box.vm.guest == :windows
        upload_path = "c:\\Windows\\temp\\script_provisioning.ps1"
    end
    
    privileged = true
    privileged = args["privileged"] == true unless args["privileged"].nil?
    box.vm.provision "script:custom",
        type: :shell,
        upload_path: upload_path,
        inline: args["script"],
        privileged: privileged
end
