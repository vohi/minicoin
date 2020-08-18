require 'socket'

def mutagen_provision(box, role_params)
    address = Socket.ip_address_list.detect{|intf| intf.ipv4_private? }
    ip_address = address.ip_address
    role_params["mutagen_host_ip"] = ip_address

    name = role_params["boxname"]
    paths = role_params["paths"]
    role_params.delete("paths")
    alphas = []
    betas = []
    paths.each do |path|
        if path.is_a?(String)
            alphas << path
            beta = path
            if box.vm.guest == :windows
                beta = beta.gsub("/", "\\").gsub("~", "C:\\Users\\vagrant")
            end
            betas << beta
        elsif path.is_a?(Hash)
            path.each do |alpha, beta|
                alphas << alpha
                if box.vm.guest == :windows
                    beta = beta.gsub("/", "\\").gsub("~", "C:\\Users\\vagrant")
                end
                betas << beta
            end
        else
            throw "Argument error: expecting 'paths' to be a list of strings or hashes from source to destination"
        end
    end
    role_params["alpha"] = alphas
    role_params["beta"] = betas

    key_file = "#{$PWD}/.vagrant/machines/#{name}/mutagen"
    authorized_keys = "#{$HOME}/.ssh/authorized_keys"

    box.trigger.before [:up, :provision] do |trigger|
        trigger.name = "Generating mutagen key pair and authorizing guest"
        trigger.ruby do |e,m|
            if !File.file?(key_file)
                `ssh-keygen -f #{key_file} -C mutagen@#{name} -q -N \"\"`
                public_key = File.read("#{key_file}.pub")
                open(authorized_keys, 'a') do |file|
                    file.puts "#{public_key}"
                end
                File.chmod(0600, authorized_keys)
            end
        end
    end

    box.trigger.before [:destroy] do |trigger|
        trigger.name = "Removing mutagen key pair and de-authorising guest"
        trigger.ruby do |e,m|
            File.open("#{authorized_keys}.new", 'w') do |out|
                out.chmod(File.stat(authorized_keys).mode)
                File.foreach(authorized_keys) do |line|
                    out.puts line unless line =~ /mutagen@#{name}/
                end
            end
            File.rename("#{authorized_keys}.new", authorized_keys)
            File.delete(key_file) if File.exist?(key_file)
            File.delete("#{key_file}.pub") if File.exist?("#{key_file}.pub")
        end
    end

    if ["up", "provision", "reload"].include? ARGV[0]
        # needs to be id_rsa, mutagen doesn't allow specifying an ssh identity file
        if box.vm.guest == :windows
            dest = "C:\\Users\\vagrant\\.ssh\\id_rsa"
        else
            dest = "~/.ssh/id_rsa"
        end
        box.vm.provision "file", source: key_file, destination: dest
    end
end
