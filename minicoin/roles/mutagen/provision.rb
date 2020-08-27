require 'socket'
require 'open3'

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
                if role_params["reverse"] == true
                    beta = beta.gsub("~", "/Users/vagrant")
                else
                    beta = beta.gsub("/", "\\").gsub("~", "C:\\Users\\vagrant")
                end
            end
            betas << beta
        elsif path.is_a?(Hash)
            path.each do |alpha, beta|
                alphas << alpha
                if box.vm.guest == :windows
                    if role_params["reverse"] == true
                        beta = beta.gsub("~", "/Users/vagrant")
                    else    
                        beta = beta.gsub("/", "\\").gsub("~", "C:\\Users\\vagrant")
                    end
                end
                betas << beta
            end
        else
            raise "Argument error: expecting 'paths' to be a list of strings or hashes from source to destination"
        end
    end
    role_params["alpha"] = alphas
    role_params["beta"] = betas

    if role_params["reverse"] == true
        box.vm.provision "mutagen_init", type: :local_command,
            commands: [
                "ssh-keyscan #{box.vm.hostname} >> ~/.ssh/known_hosts",
            ]

        box.trigger.before :destroy do |trigger|
            hostip, stderr, status = Open3.capture3("dig #{box.vm.hostname} +short")
            trigger.name = "Removing #{box.vm.hostname} from list of known hosts"
            known_hosts = "#{$HOME}/.ssh/known_hosts"
            trigger.ruby do |env, machine|
                stdout, stderr, status = Open3.capture3("mutagen sync terminate minicoin-#{name}")
                File.open("#{known_hosts}.new", 'w') do |out|
                    out.chmod(File.stat(known_hosts).mode)
                    File.foreach(known_hosts) do |line|
                        out.puts line unless line =~ /#{box.vm.hostname}/ || line =~ /#{hostip}/
                    end
                end
                File.rename("#{known_hosts}.new", known_hosts)
            end
        end

        sync = 0
        alphas.each do |alpha|
            beta = betas[sync]
            box.vm.provision "mutagen_#{sync}", type: :local_command,
                commands: [ "mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin-#{name} #{alpha} vagrant@#{box.vm.hostname}:#{beta}" ]
            sync += 1
        end
        return
    end

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
