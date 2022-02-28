def mutagen_provision(box, name, role_params, machine)
    paths = role_params["paths"]
    role_params.delete("paths")

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
    return false if paths.empty? # nothing to do
    paths.each do |alpha, beta|
        alphas << alpha
        if box.vm.guest == :windows
            beta.gsub!("~", "#{box.minicoin.guest_homes}/vagrant")
            beta.gsub!($HOME, "#{box.minicoin.guest_homes}/vagrant")
            beta.gsub!("\\", "/")
            beta.gsub!(/^\//, "C:/")
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
