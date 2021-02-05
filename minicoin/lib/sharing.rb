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

def mac_setup_sshfs(mac, machine)
    name = machine["name"]
    key_filename = "#{$PWD}/.vagrant/machines/#{name}/minicoin"
    begin
        File.open(key_filename, "a+") do |f|
        end
    rescue
    end
    
    mac.vm.provider :virtualbox do |vb, box|
        # on VirtualBox, folder sharing is not supported on BSD/Mac systems
        # instead, mount shared folders via sshfs
        box.vm.synced_folder ".", "/minicoin", disabled: true 
        
        # ensure users private key is on the guest for authenticating back to host
        authorized_keys = "#{$HOME}/.ssh/authorized_keys"
        
        # generate keys and authorize the guest to access the host
        box.trigger.before [:up] do |trigger|
            trigger.name = "Generating sshfs key pair and authorizing guest"
            trigger.ruby do |e,m|
                if File.zero?(key_filename)
                    File.delete(key_filename)
                end
                if !File.file?(key_filename)
                    `ssh-keygen -f #{key_filename} -C minicoin@#{name} -q -N \"\"`
                    public_key = File.read("#{key_filename}.pub")
                    open(authorized_keys, 'a') do |file|
                        file.puts "#{public_key}"
                    end
                    File.chmod(0600, authorized_keys)
                end
            end
        end
        
        # delete the keys, and de-authorize the guest
        box.trigger.after [:destroy] do |trigger|
            trigger.name = "Removing sshfs key pair and de-authorising guest"
            trigger.ruby do |e,m|
                File.open("#{authorized_keys}.new", 'w') do |out|
                    out.chmod(File.stat(authorized_keys).mode)
                    File.foreach(authorized_keys) do |line|
                        out.puts line unless line =~ /minicoin@#{name}/
                    end
                end
                File.rename("#{authorized_keys}.new", authorized_keys)
                File.delete(key_filename) if File.exist?(key_filename)
                File.delete("#{key_filename}.pub") if File.exist?("#{key_filename}.pub")
            end
        end
    end

    # upload the private key to the guest
    if File.exist?(key_filename)
        mac.vm.provision "sshfs key upload",
            type: :file,
            source: key_filename,
            destination: ".ssh/#{$USER}"
        mac.vm.provision "sshfs key permissions",
            type: :shell,
            inline: "chmod 0600 .ssh/#{$USER}",
            upload_path: "/tmp/vagrant-shell/start_sshfs.sh"
    end
    mac.vm.provision "sshfs startup",
        type: :file,
        source: "lib/local.sshfs.plist",
        destination: "/tmp/local.sshfs.plist"
end

def sshfs_share_folders(box, shares)
    mount_lines = []
    shares.each do |share|
        share.each do |host_path, guest_path|
            # on VMware, everything works normal
            box.vm.provider :vmware_desktop do |vmware, box|
                box.vm.synced_folder host_path, guest_path
            end
            
            guest_base = guest_path.split('/').last
            
            if host_path == "."
                host_path = $PWD
            end
            if $is_windows_host
                host_path = "/#{host_path}".gsub("\\", "/")
            end
            
            sshfs_options = \
            "reconnect,allow_other,defer_permissions,cache=no," \
            "IdentityFile=/Users/vagrant/.ssh/#{$USER},StrictHostKeyChecking=no," \
            "volname=#{guest_base}"
            mount_lines << "[ -d #{guest_path} ] || mkdir -p '#{guest_path}'"
            mount_lines << "df #{guest_path} 2> /dev/null | grep $HOST_IP > /dev/null || /usr/local/bin/sshfs -o #{sshfs_options} #{$USER}@${HOST_IP}:#{host_path} #{guest_path}"
        end
    end
    
    upload_path = "/Users/vagrant/sshfs_mount.sh"
    
    mount_command = "
if [ ! -f /usr/local/bin/sshfs ]; then
    >&2 echo \"No sshfs, nothing to do\"
    exit 0
fi
export HOST_IP=$(echo $SSH_CONNECTION | cut -f 1 -d ' ')
#{mount_lines.join("\n")}
if ! (launchctl list | grep \"local.sshfs.plist\" > /dev/null); then
    echo \"Installing launch agent\"
    sed -i.bak \"s/\\$SSH_CONNECTION/$SSH_CONNECTION/g\" /tmp/local.sshfs.plist
    mkdir -p /Library/LaunchAgents > /dev/null
    mv /tmp/local.sshfs.plist /Library/LaunchAgents/local.sshfs.plist
    chown root:wheel /Library/LaunchAgents/local.sshfs.plist
    chmod 644 /Library/LaunchAgents/local.sshfs.plist
    launchctl load -w /Library/LaunchAgents/local.sshfs.plist
    if [ $? -gt 0 ]; then
        >&2 echo \"Error installing launch agent\"
        cat /tmp/sshfs_mount.err
    fi
fi
"
    
    box.vm.provision "sshfs_mount",
        type: :shell,
        upload_path: "#{upload_path}",
        inline: mount_command
end


def share_folders(box, machine, shares)
    shares = Marshal.load(Marshal.dump(shares))
    exp_shares = []
    shares.each do |share|
        if share.nil?
            next
        end
        share.each do |host, guest|
            host = expand_env(host, nil)
            if (host == $PWD)
                host = "." # this prevents duplicate PWD sharing from vagrant
            end
            guest = expand_env(guest, box)
            if guest.nil? || host.nil?
                STDERR.puts "==> #{machine['name']}: Unexpanded environment variable in '#{share}' - skipping share"
                next
            end
            exp_shares << { host => guest }
        end
    end

    machine["actual_shared_folders"] = {}
    machine["fs_mappings"] = {}
    
    if box.vm.guest == :darwin
        mac_setup_sshfs(box, machine)
        sshfs_share_folders(box, exp_shares)
        return
    end
    
    win_links = {}
    exp_shares.each do |share|
        share.each do |host, guest|
            if box.vm.guest == :windows
                guest = guest.gsub("/", "\\")
                # on windows, shares become network locations; win_links contains the link
                # we create to the network location
                win_guest = guest.gsub(/^\\/, "C:\\")
                # for the sharing itself, we only care about the basename. We assume they are unique
                guest = "#{guest.split('\\')[-1]}"
                win_links[guest] = win_guest
                guest = "/#{guest}"
            end
            machine["actual_shared_folders"][host] = guest
            machine["fs_mappings"][host] = win_links[guest[1..-1]] || guest
            box.vm.synced_folder host, guest
        end
    end
    if box.vm.guest == :windows
        win_link_folders(box, win_links)
    end
end
