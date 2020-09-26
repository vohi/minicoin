# expand environment variables in parameters
# and adjust any occurence of $HOME to the home on the guest
def expand_env(value, box)
    guest_sub_indices = []
    if !value.is_a?(String)
        return value
    end
    while (matches = value.match(/\$([A-Za-z0-9_]+)/))
        env_name = matches[1]
        match_index = matches.begin(1)
        # guest substitution
        if value[match_index-2] == '$'
            value[match_index-2] = '?'
            value[match_index-1] = ''
            guest_sub_indices << match_index-2
            next
        end
        if env_name == ""
            break
        end
        env_val = ENV[env_name]
        if env_val.nil?
            return nil
        end
        
        value = value.sub("$#{env_name}", env_val)
        if !box.nil? && box.vm.guest == :windows
            value = value.gsub("/C:\\", "C:\\")
            value = value.gsub("/", "\\\\")
        end
    end
    guest_sub_indices.each do |i|
        value[i] = '$'
    end
    return value
end
