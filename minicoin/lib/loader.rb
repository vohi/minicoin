def merge_yaml(first, second)
    if first.nil?
        return second
    end

    # user can overwrite defaults
    if second.nil?
        return nil
    end
    if second.is_a?(Array) && second[0].nil?
        if !first.is_a?(Array) && second.length == 2
            return second[1]
        end
        return second[1..-1]
    end

    if first.is_a?(Array)
        if second.is_a?(Array)
            result = first + second
        else
            result = first.clone
            result << second
        end
        result = result.uniq
        return result
    end

    if first.is_a?(Hash)
        if second.is_a?(Hash)
            result = first.clone
            second.each do |key, value|
                if result.has_key?(key)
                    if value.nil?
                        result.delete(key)
                    else
                        new_value = merge_yaml(result[key], value)
                        result[key] = new_value
                    end
                else
                    result[key] = value
                end
            end
            return result;
        end
        # already a value, assume flattened hash
        if first.has_value?(second)
            return first
        end
        STDERR.puts "Can't insert #{second.class} '#{second}' into hash #{first}"
        return first
    end

    return second
end

def load_settings(yaml, user_yaml)
    # a hash
    $settings = yaml["settings"]
    $settings = {} if $settings.nil?

    user_settings = user_yaml["settings"] unless user_yaml.nil?
    $settings = merge_yaml($settings, user_settings) unless user_settings.nil?

    home_share = $settings["home_share"] || $HOME
    home_share = home_share.gsub("~", "$HOME")
    home_share = expand_env(home_share, nil)
    ENV["HOME_SHARE"] = home_share
    $settings["defaults"] = {} if $settings["defaults"].nil?
    yaml["settings"] = $settings
end

def load_urls(yaml, user_yaml)
    # a hash of arrays
    $urls = yaml["urls"]
    user_urls = user_yaml["urls"] unless user_yaml.nil?
    $urls = merge_yaml($urls, user_urls) unless user_urls.nil?
    yaml["urls"] = $urls
end

def load_boxes(yaml, user_yaml)
    machines = yaml["machines"]

    user_machines = user_yaml["machines"] unless user_yaml.nil?
    if user_machines.nil?
        user_machines = []
    elsif user_machines.length > 0 && user_machines.first.nil?
        machines = []
    end
    user_machines.each do |user_machine|
        next if user_machine.nil?
        idx = machines.find_index {|m| m["name"] == user_machine["name"] }
        unless idx.nil?
            new_machine = merge_yaml(machines[idx], user_machine)
            machines[idx] = new_machine
        else
            machines << user_machine
        end
    end

    machines.each do |machine|
        machine_name = machine["name"]
        defaults = $settings["defaults"].dup
        $settings.each do |machine_exp, machine_settings|
            next if machine_settings.nil?
            if machine_exp.start_with?("/") && machine_exp.end_with?("/") && machine_name.match?(machine_exp[1..-2])
                defaults = merge_yaml(defaults, machine_settings)
            end
        end
        (defaults || {}).each do |setting, value|
            # make deep copies
            default_value = value.dup
            if machine[setting].nil?
                machine[setting] = default_value
            else
                machine[setting] = merge_yaml(default_value, machine[setting])
            end
        end
    end

    yaml["machines"] = machines
    return machines
end

def load_includes(yaml, basedir)
    includes = yaml["includes"] || yaml["Include"] unless yaml.nil?
    
    unless includes.nil?
        includes.each do |include|
            include_file = File.join(basedir, include)
            begin
                include_yaml = YAML.load_file(include_file)
                include_yaml = load_includes(include_yaml, File.dirname(include_file))
                include_yaml.each do |section, data|
                    yaml[section] = merge_yaml(yaml[section], data) unless section == "includes"
                end
            rescue => error
                STDERR.puts "Error loading file #{include_file}: #{error}"
            end
        end
    end
    
    return yaml
end

def merge_roles(machines)
    # post processing of roles: if a role is defined multiple times, merge them
    machines.each do |machine|
        roles = machine["roles"]
        unless roles.nil?
            role_set = []
            role_indices = {}
            index = 0
            roles.each do |role|
                if role.is_a?(Hash)
                    rolename = role["role"]
                else
                    rolename = role
                end
                if rolename == "script" || rolename == "install"
                    role_set << role
                    index += 1
                elsif role_indices.has_key?(rolename)
                    oldindex = role_indices[rolename]
                    role_set[oldindex] = merge_yaml(role_set[oldindex], role)
                else
                    role_indices[rolename] = index
                    role_set << role
                    index += 1
                end
            end
            role_set.each do |role|
                machine["roles"] = role_set
            end
        end
    end
end

def merge_boxes(machines)
    machines.each do |machine|
        index = machines.rindex {|m| m["name"] == machine["name"] && m != machine}
        unless index.nil?
            duplicate = machines[index]
            duplicate.each do |key, value|
                machine[key] = merge_yaml(machine[key], value)
            end
            machines.delete_at(index)
        end
    end

    machines.each do |machine|
        basename = machine["extends"]
        unless basename.nil?
            basemachine = machines.select{|m| m["name"] == basename}.first
            basemachine.each do |key, value|
                machine_value = machine[key]
                if !machine.has_key?(key)
                    machine[key] = value
                elsif key != "name"
                    machine[key] = merge_yaml(value, machine_value)
                end
            end
            machine.delete("extends")
        end
    end
end

def find_config(root, config_name)
    while !Dir.exist?("#{root}/#{config_name}") do
        old_root = root
        root = File.dirname(root)
        if File.identical?(root, old_root)
            root = nil
            break
        end
    end
    root = nil unless root.nil? || Dir.exists?(root)
    return root
end


def load_minicoin()
    begin # see tests/autotest.rb
        load_testmachines()
    rescue NoMethodError => error # Not running autotest, continue
    rescue => error
        raise
    end
    
    global_file = File.join($PWD, 'minicoin.yml')
    yaml = YAML.load_file(global_file)
    
    user_file = File.join($HOME, 'minicoin/minicoin.yml')
    user_yaml = nil
    if File.file?(user_file)
        user_yaml = YAML.load_file(user_file)
    end
    
    local_yaml = nil
    project_dir = ENV['MINICOIN_PROJECT_DIR']
    if project_dir && project_dir != $PWD && project_dir != $HOME
        local_file = File.join(project_dir, '.minicoin/minicoin.yml')
        if File.file?(local_file)
            local_yaml = YAML.load_file(local_file)
        end
    end

    yaml = load_includes(yaml, $PWD)
    user_yaml = load_includes(user_yaml, $HOME)
    local_yaml = load_includes(local_yaml, project_dir)

    load_settings(yaml, user_yaml)
    load_settings(yaml, local_yaml)

    yaml.each do |key, value|
        begin
            require_relative "#{key}_loader.rb"
            eval("machines = load_boxes(yaml, load_#{key}(yaml))")
        rescue LoadError => e
        end
    end
    machines = load_boxes(yaml, user_yaml)
    machines = load_boxes(yaml, local_yaml)

    # inheritance after override resolution
    merge_boxes(machines)
    # role merging once each box is fully defined
    merge_roles(machines)

    load_urls(yaml, user_yaml)
    load_urls(yaml, local_yaml)

    $TEST_OUTPUT=yaml

    return machines
end
