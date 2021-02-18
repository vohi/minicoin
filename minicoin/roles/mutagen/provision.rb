require 'socket'
require 'open3'

$HOST_HAS_MUTAGEN = nil

# work around mutagen bug with Windows 20H2's OpenSSH server
def upload_mutagen_agent(machine)
    if machine.config.vm.guest != :windows
        machine.ui.error("Workaround not implemented for #{machine.config.vm.guest}")
        return
    end
    agent_binary = "windows_amd64"

    stdout, stderr, status = Open3.capture3("which mutagen")
    if status != 0
        machine.ui.error("Mutagen not found on host machine")
        return
    end
    mutagen_exe = stdout.strip
    if File.symlink?(mutagen_exe)
        mutagen_link = mutagen_exe
        mutagen_exe = File.readlink(mutagen_exe)
        unless mutagen_exe.start_with?("/") # relative path, resolve
            mutagen_exe = File.realpath("#{File.dirname(mutagen_link)}/#{mutagen_exe}")
        end
    end
    stdout, stderr, status = Open3.capture3("mutagen version")
    mutagen_version = stdout.strip
    mutagen_bin = File.dirname(mutagen_exe)
    machine.ui.info("mutagen at #{mutagen_bin} is version #{mutagen_version}")
    mutagen_agents = File.join(File.dirname(mutagen_bin), "libexec", "mutagen-agents.tar.gz")
    if File.exist?(mutagen_agents)
        machine.ui.info("Extracting #{agent_binary} from #{mutagen_agents}")
        `cd /tmp; tar -zxvf #{mutagen_agents} #{agent_binary}`
        if File.exist?("/tmp/#{agent_binary}")
            machine.ui.info("Uploading #{agent_binary} to #{machine.ssh_info[:host]}:#{machine.ssh_info[:port]}")
            `ssh -p #{machine.ssh_info[:port]} vagrant@#{machine.ssh_info[:host]} mkdir -p .mutagen/agents/#{mutagen_version} 2> /dev/null`
            `scp -P #{machine.ssh_info[:port]} /tmp/#{agent_binary} vagrant@#{machine.ssh_info[:host]}:.mutagen/agents/#{mutagen_version}/mutagen-agent.exe`
        end
    end
end

def mutagen_host_to_guest(box, name, alphas, betas, ignores)
    session_name = "minicoin-#{name.gsub('.', '')}"
    box.trigger.before :destroy do |trigger|
        trigger.name = "Shutting down mutagen sync to #{name} and removing from known hosts"
        trigger.ruby do |env, machine|
            stdout, stderr, status = Open3.capture3("mutagen sync terminate #{session_name}")
            ssh_info = machine.ssh_info
            unless ssh_info.nil?
                keyname = "[127.0.0.1]"
                keyname = "#{ssh_info[:host]}" unless ssh_info[:host] == "127.0.0.1"
                keyname = "#{keyname}:#{ssh_info[:port]}" if ssh_info[:port] != 22
                `ssh-keygen -R #{keyname}`
            end
        end
    end
    box.trigger.before [ :halt, :suspend ] do |trigger|
        trigger.name = "Pausing mutagen sync to #{name}"
        trigger.ruby do |env, machine|
            stdout, stderr, status = Open3.capture3("mutagen sync pause #{session_name}")
        end
    end
    box.trigger.after [ :up, :resume ] do |trigger|
        trigger.name = "Resuming mutagen sync to #{name}"
        trigger.ruby do |env, machine|
            stdout, stderr, status = Open3.capture3("echo yes | mutagen sync resume #{session_name}")
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
        alpha = alpha.gsub("~", ENV['HOME'])
        beta = betas[sync]
        mutagen_create = lambda do |machine|
            ssh_info = machine.ssh_info
            if ssh_info.nil?
                machine.ui.error("Error setting up mutagen sync to #{machine} - no SSH info!")
                raise "Error setting up mutagen sync: no ssh info available for #{name}!"
            else
                stdout, stderr, status = Open3.capture3("mutagen sync list #{session_name}")
                if (status == 0)
                    status = -1 unless stdout.include?(alpha)
                end
                if status != 0
                    command = "mutagen sync create --sync-mode one-way-replica --ignore-vcs --name #{session_name} --label minicoin=#{name}"
                    unless ignores.nil?
                        ignores.each do |ignore|
                            command += " -i #{ignore}"
                        end
                    end
                    stdout, stderr, status = Open3.capture3("echo yes | #{command} #{alpha} vagrant@#{ssh_info[:host]}:#{ssh_info[:port]}:#{beta}")
                    if status != 0
                        machine.ui.warn("Attempting workaround to set up mutagen sync to #{machine.ssh_info[:host]}:#{ssh_info[:port]}: #{stderr}")
                        upload_mutagen_agent(machine)
                        stdout, stderr, status = Open3.capture3("echo yes | #{command} #{alpha} vagrant@#{ssh_info[:host]}:#{ssh_info[:port]}:#{beta}")
                    end
                    if status != 0
                        machine.ui.error("Error setting up mutagen sync to #{machine.ssh_info[:host]}:#{ssh_info[:port]}: #{stderr}")
                    end
                else
                    machine.ui.error("Error setting up mutagen sync to #{machine.ssh_info[:host]}:#{ssh_info[:port]}: #{stderr}")
                end
            end
        end
        box.vm.provision "mutagen:sync_create #{alpha}",
            type: :local_command,
            code: mutagen_create
        sync += 1
    end
end

def mutagen_guest_to_host(box, name, alphas, betas, ignores)
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

def mutagen_provision(box, name, role_params, machine)
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
                        beta = beta.gsub("/", "\\").gsub("~", "#{ENV['GUEST_HOMES']}\\vagrant")
                    else    
                        beta = beta.gsub("~", "#{ENV['GUEST_HOMES']}/vagrant")
                        beta = beta.gsub("\\", "/")
                    end
                else
                    beta = beta.gsub("~", "#{ENV['GUEST_HOMES']}/vagrant")
                end
                betas << beta
                box.minicoin.fs_mappings[alpha] = beta
            end
        else
            raise "Argument error: expecting 'paths' to be a list of strings or hashes from source to destination"
        end
    end
    role_params["alpha"] = alphas
    role_params["beta"] = betas

    if role_params["reverse"] == true
        mutagen_guest_to_host(box, name, alphas, betas, role_params["ignores"])
    else
        mutagen_host_to_guest(box, name, alphas, betas, role_params["ignores"])
    end
end
