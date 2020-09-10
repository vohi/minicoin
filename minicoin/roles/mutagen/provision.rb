require 'socket'
require 'open3'

$HOST_HAS_MUTAGEN = nil

def mutagen_host_to_guest(box, name, alphas, betas)
    box.trigger.before :destroy do |trigger|
        trigger.name = "Shutting down mutagen sync to #{name} and removing from known hosts"
        trigger.ruby do |env, machine|
            known_hosts = "#{$HOME}/.ssh/known_hosts"
            stdout, stderr, status = Open3.capture3("mutagen sync terminate minicoin-#{name}")
            ssh_info = machine.ssh_info
            unless ssh_info.nil?
                File.open("#{known_hosts}.new", 'w') do |out|
                    out.chmod(File.stat(known_hosts).mode)
                    File.foreach(known_hosts) do |line|
                        if ssh_info[:host] == "127.0.0.1"
                            out.puts line unless line.start_with?("[127.0.0.1]:#{ssh_info[:port]} ")
                        else
                            out.puts line unless line.start_with?(ssh_info[:host])
                        end
                    end
                end
                File.rename("#{known_hosts}.new", known_hosts)
            end
        end
    end

    if box.vm.guest == :windows
        mutagen_key_destination = "..\\.ssh\\#{$USER}.pub"
        mutagen_key_add = "Get-Content -Path $env:USERPROFILE\\.ssh\\#{$USER}.pub | Add-Content -Path $env:USERPROFILE\\.ssh\\authorized_keys -Encoding utf8"
        mutagen_key_add_script = "c:\\windows\\temp\\mutagen_key_add.ps1"
    else
        mutagen_key_destination = ".ssh/#{$USER}.pub"
        mutagen_key_add = "cat #{mutagen_key_destination} >> .ssh/authorized_keys"
        mutagen_key_add_script = "/tmp/vagrant-shell/mutagen_key_add.sh"
    end
    box.vm.provision "mutagen:key upload",
        type: :file,
        source: "~/.ssh/id_rsa.pub",
        destination: mutagen_key_destination
    box.vm.provision "mutagen:key add",
        type: :shell,
        inline: mutagen_key_add,
        upload_path: mutagen_key_add_script,
        privileged: false
    sync = 0
    alphas.each do |alpha|
        beta = betas[sync]
        mutagen_create = lambda do |machine|
            ssh_info = machine.ssh_info
            if ssh_info.nil?
                machine.ui.error("Error setting up mutagen sync to #{machine.ssh_info[:host]}: #{stderr}")
                raise "Error setting up mutagen sync: no ssh info available for #{name}!"
            else
                stdout, stderr, status = Open3.capture3("echo yes | mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin-#{name} #{alpha} vagrant@#{ssh_info[:host]}:#{ssh_info[:port]}:#{beta}")
                if status != 0
                    machine.ui.warn("Error setting up mutagen sync to #{machine.ssh_info[:host]}: #{stderr}")
                end
            end
        end
        box.vm.provision "mutagen:sync_create #{sync}",
            type: :local_command,
            code: mutagen_create
        sync += 1
    end
end

def mutagen_guest_to_host(box, name, alphas, betas)
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
        box.vm.provision "mutagen(reverse):key upload",
            type: :file,
            source: key_file,
            destination: dest
    end
end

def mutagen_provision(box, role_params)
    name = role_params["boxname"]
    paths = role_params["paths"]
    role_params.delete("paths")

    # autodetect if mutagen is locally installed; if not, try to install it on the guest
    if role_params['reverse'].nil?
        if $HOST_HAS_MUTAGEN.nil?
            begin
                `mutagen version`
                $HOST_HAS_MUTAGEN = true
            rescue
                $HOST_HAS_MUTAGEN = false
            end
        end
        role_params["reverse"] = !$HOST_HAS_MUTAGEN
    end

    if role_params["reverse"] == true
        address = Socket.ip_address_list.detect{|intf| intf.ipv4_private? }
        ip_address = address.ip_address
        role_params["mutagen_host_ip"] = ip_address
    end

    alphas = []
    betas = []
    paths.each do |path|
        if path.is_a?(String)
            path = { path => path }
        end
        if path.is_a?(Hash)
            path.each do |alpha, beta|
                alphas << alpha
                if box.vm.guest == :windows
                    if role_params["reverse"] == true
                        beta = beta.gsub("/", "\\").gsub("~", "C:\\#{ENV['GUEST_HOMES']}\\vagrant")
                    else    
                        beta = beta.gsub("~", "/#{ENV['GUEST_HOMES']}/vagrant")
                    end
                else
                    beta = beta.gsub("~", "/#{ENV['GUEST_HOMES']}/vagrant")
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
        mutagen_guest_to_host(box, name, alphas, betas)
    else
        mutagen_host_to_guest(box, name, alphas, betas)
    end
end
