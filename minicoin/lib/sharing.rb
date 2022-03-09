## Folder sharing helpers
def win_link_folders(box, links)
    symlink_lines = []
    links.each do |net, local|
        local_symlink = local
        local_segments = local.split("\\")
        local_symlink = "#{local_segments[0]}\\#{local_segments[-1]}"
        symlink_lines << "if (Test-Path -Path \"$($Hostname)#{net}\") {"
        symlink_lines << "  New-Item -ItemType SymbolicLink -Path #{local_symlink} -Target \"$($Hostname)#{net}\" -Force"
        if local_segments.length > 2
            symlink_lines << "  (Get-Item -Path #{local_symlink}).Attributes += 'Hidden'"
            # we create a junction because qmake would otherwise follow the symlink to a \\HOSTNAME\share
            symlink_lines << "  if (Test-Path -Path \"#{local}\") { cmd /c \"rd #{local}\" }"
            symlink_lines << "  New-Item -ItemType Junction -Path \"#{local}\" -Target \"#{local_symlink}\" -Force | Out-Null"
        end
        symlink_lines << "}"
    end
    return if symlink_lines.empty?

    link_cmd = <<-SCRIPT
function Link-Host {
    Param($Hostname)
    #{symlink_lines.join("\n    ")}
}
Link-Host -Hostname "\\\\VBOXSVR\\" | Out-Null
Link-Host -Hostname "\\\\vmware-host\\Shared Folders\\-" | Out-Null
SCRIPT

    box.vm.provision "win_link_folders",
        type: :shell,
        inline: link_cmd
end

def adjust_guest_path(path, box)
    path = path.gsub("~", "#{box.minicoin.guest_homes}/vagrant")
    path.gsub!($HOME, "#{box.minicoin.guest_homes}/vagrant")
    if box.vm.guest == :windows
        path.gsub!("\\", "/")
        path.gsub!(/^\//, "C:/")
    end
    path
end

def mutagen_share(box, role_params, machine)
    paths = role_params["paths"]
    role_params.delete("paths")

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
    sessions = {}
    paths.each do |alpha, beta|
        beta = adjust_guest_path(beta, box)
        sessions[alpha] = beta
    end
    box.minicoin.fs_mappings.merge!(sessions)

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

def share_folders(box, machine, shares)
    return if shares.nil?

    raise "shared_folders needs to be a list of mappings" if !shares.respond_to?(:each)
    shares = Marshal.load(Marshal.dump(shares))
    default_shares = {}
    shares.each do |share|
        next if share.nil?
        if share.is_a?(Array)
            if share.count > 1 && share[1].respond_to?(:each) # if the value is an iterable, then the key is the type
                share_type = share[0]
                share = share[1]
            elsif share.count == 2
                share = { share[0] => share[1] }
            end
        end
        if share.is_a?(Array)
            share_hash = {}
            share.each do |path|
                if path.is_a?(Hash)
                    share_hash.merge!(path)
                else
                    share_hash[path] = path
                end
            end
            share = share_hash
        end
        share.each do |host, guest|
            # each entry could be just alpha; or alpha => beta or host => alpha; guest => beta
            guest ||= host
            host = expand_env(host)
            host = "." if host == $PWD # this prevents duplicate PWD sharing from vagrant
            guest = expand_env(guest)
            if guest.nil? || host.nil?
                STDERR.puts "==> #{machine['name']}: Unexpanded environment variable in '#{share}' - skipping share"
                next
            end
            if !box.nil? && box.vm.guest == :windows
                guest = guest.gsub("/C:\\", "C:\\")
                guest = guest.gsub("/", "\\\\")
            end

            case share_type
            when 'mutagen'
                mutagen_share(box, { "paths" => { host => guest } }, machine)
            when 'rsync'
                guest = adjust_guest_path(guest, box)
                host = host.gsub("~", $HOME)
                box.vm.synced_folder host, guest, type: :rsync
                box.minicoin.fs_mappings.merge!({host => guest})
            when 'disabled'
                default_shares.delete(host)
            else
                default_shares[host] = guest
            end
        end
    end

    if shares.has_key?("disabled") && shares["disabled"] == nil
        default_shares = {}
    end

    # if the minicoin folder sharing is disabled, then upload the needed guest-side scripts
    unless default_shares.include?($PWD) || default_shares.include?(".")
        box.vm.synced_folder ".", "/opt/minicoin", disabled: true
        if box.vm.guest == :windows
            box.vm.provision "minicoin guest scripts:upload",
                type: :file,
                source: "./util",
                destination: "C:\\opt\\minicoin\\"
        else
            box.vm.provision "minicoin guest scripts:script",
                type: :shell,
                inline: "sudo mkdir -p /opt/minicoin/util; chown -R vagrant /opt/minicoin",
                upload_path: "/tmp/vagrant-shell_minicoin_guest_scripts"
            box.vm.provision "minicoin guest scripts:upload",
                type: :file,
                source: "./util",
                destination: "/opt/minicoin/"
        end
    end

    # set up default shares, take care of resulting network drives on guests
    win_links = {}
    default_shares.each do |host, guest|
        if box.vm.guest == :windows
            guest.gsub!("/", "\\")
            # on windows, shares become network locations; win_links contains the link
            # we create to the network location
            win_guest = guest.gsub(/^\\/, "C:\\")
            # for the sharing itself, we only care about the basename. We assume they are unique
            guest = "#{guest.split('\\')[-1]}"
            win_links[guest] = win_guest
            guest = "/#{guest}"
        end
        options = {}
        options[:type] = machine["shared_folder_type"] if machine["shared_folder_type"]
        box.vm.synced_folder host, guest, options
        # host-side, slashes are always unix-style
        host_path = host.gsub("\\", "/")
        box.minicoin.default_shared_folders[host_path] = guest
        box.minicoin.fs_mappings[host_path] = win_links[guest[1..-1]] || guest
    end
    win_link_folders(box, win_links) if box.vm.guest == :windows
end
