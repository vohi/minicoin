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

def share_folders(box, machine, shares)
    shares = Marshal.load(Marshal.dump(shares))
    exp_shares = []
    shares.each do |share|
        next if share.nil?
        share.each do |host, guest|
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
    
            exp_shares << { host => guest }
        end
    end
    
    win_links = {}
    exp_shares.each do |share|
        share.each do |host, guest|
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
            box.minicoin.actual_shared_folders[host] = guest
            box.minicoin.fs_mappings[host] = win_links[guest[1..-1]] || guest
            options = {}
            options[:type] = machine["shared_folder_type"] if machine["shared_folder_type"]
            box.vm.synced_folder host, guest, options
        end
    end
    win_link_folders(box, win_links) if box.vm.guest == :windows
end
