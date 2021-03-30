# expand environment variables in parameters
# and adjust any occurence of $HOME to the home on the guest
def expand_env(value)
    guest_sub_indices = []
    return value unless value.is_a?(String)

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
        break if env_name == ""
        env_val = ENV[env_name]
        return nil if env_val.nil?
        
        value = value.sub("$#{env_name}", env_val)
    end
    guest_sub_indices.each do |i|
        value[i] = '$'
    end
    return value
end
