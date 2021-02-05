require 'digest'

def script_provision(box, name, args, machine)
    script = args["script"]
    if !script.is_a?(String)
        raise "Argument error: expecting a 'script' string"
    end
    name = args["name"]
    if name
        scriptid = Digest::MD5.hexdigest(script)
    else
        name = Digest::MD5.hexdigest(script)
        scriptid = name
    end
    upload_path = "/tmp/vagrant-shell/script_provisioning_#{scriptid}.sh"
    if box.vm.guest == :windows
        upload_path = "c:\\Windows\\temp\\script_provisioning_#{scriptid}.ps1"
    end
    
    privileged = args["privileged"] || true
    box.vm.provision "script:#{name}",
        type: :shell,
        upload_path: upload_path,
        inline: args["script"],
        privileged: privileged
end
