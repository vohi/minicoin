require 'socket'
require 'open3'

$HOST_HAS_MUTAGEN = nil

def mutagen_guest_to_host(box, name)
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
    sessions = {}
    if paths.is_a?(String)
        paths = { paths.dup => paths.dup }
    elsif paths.is_a?(Array)
        paths_hash = {}
        paths.each do |path|
            paths_hash[path] = path.dup
        end
        paths = paths_hash
    end
    raise "Argument error: 'paths' needs to be a list of strings, or a hash from source to destination" unless paths.is_a?(Hash)
    paths.each do |alpha, beta|
        alphas << alpha
        if box.vm.guest == :windows
            if role_params["reverse"] == true
                beta.gsub!("~", "#{box.minicoin.guest_homes}\\vagrant")
                beta.gsub!($HOME, "#{box.minicoin.guest_homes}\\vagrant")
                beta.gsub!("/", "\\")
                beta.gsub!(/^\\$/, "C:\\")
            else
                beta.gsub!("~", "#{box.minicoin.guest_homes}/vagrant")
                beta.gsub!($HOME, "#{box.minicoin.guest_homes}/vagrant")
                beta.gsub!("\\", "/")
                beta.gsub!(/^\//, "C:/")
            end
        else
            beta.gsub!("~", "#{box.minicoin.guest_homes}/vagrant")
            beta.gsub!($HOME, "#{box.minicoin.guest_homes}/vagrant")
        end
        betas << beta
        sessions[alpha] = beta
    end
    box.minicoin.fs_mappings.merge!(sessions)

    role_params["alpha"] = alphas
    role_params["beta"] = betas

    if role_params["reverse"] == true
        mutagen_guest_to_host(box, name, alphas, betas, role_params["ignores"])
    else
        sessions.each do |alpha, beta|
            ignores = [ role_params["ignores"] || [] ].flatten
            options = [ role_params["options"] || [ "--ignore-vcs" ] ].flatten
            ignores.each do |ignore|
                options << "--ignore #{ignore}"
            end
            box.vm.synced_folder alpha, beta,
                type: :mutagen,
                mount_options: options
        end
    end
end
