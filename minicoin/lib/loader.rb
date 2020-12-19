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
        if second.is_a?(Array)
            STDERR.puts "Can't insert array #{second} into hash #{first}"
            return first
        end
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
        STDERR.puts "Can't insert value #{second} into hash #{first}"
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
    user_machines = [] if user_machines.nil?
    user_machines.each do |user_machine|
        idx = machines.find_index {|m| m["name"] == user_machine["name"] }
        unless idx.nil?
            new_machine = merge_yaml(machines[idx], user_machine)
            machines[idx] = new_machine
        else
            machines << user_machine
        end
    end

    defaults = $settings["defaults"]
    unless defaults.nil?
        defaults.each do |setting, value|
            # make deep copies
            default_value = value.dup
            machines.each do |machine|
                if machine[setting].nil?
                    machine[setting] = default_value
                else
                    machine[setting] = merge_yaml(default_value, machine[setting])
                end
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
                    if role_indices.has_key?(rolename)
                        index = role_indices[rolename]
                        role_set[index] = merge_yaml(role_set[index], role)
                    else
                        role_indices[rolename] = index
                        role_set << role
                        index += 1
                    end
                else
                    role_set << role
                    role_indices[rolename] = index
                    index += 1
                end
            end
            role_set.each do |role|
                machine["roles"] = role_set
            end
        end
    end
end

def load_coinconfig(yaml)
    return {} if yaml["coin"].nil?
    return {} if !ENV['COIN_ROOT'] || !File.exist?(ENV['COIN_ROOT'])

    # do we have a project specific config file for coin?
    coin_config_root = "#{ENV['COIN_ROOT']}/platform_configs"
    config_name = File.basename(ENV['MINICOIN_PROJECT_DIR'])
    if File.exist?("#{coin_config_root}/#{config_name}.yaml")
        coin_config_file = "#{coin_config_root}/#{config_name}.yaml"
    else # if not, use the default for Qt
        coin_config_file = "#{coin_config_root}/qt5.yaml"
    end
    puts "Coin config from: #{coin_config_file}"

    coin_configs = YAML.load_file(coin_config_file)
    coin_configs = load_includes(coin_configs, coin_config_root)
    coin_configs = coin_configs["Configurations"]

    coin_machines = []
    coin_configs.each do |coin_config|
        coin_template = coin_config["Template"].split('-')
        template = coin_template
        if template[1] == "linux"
            template = "#{template[2]}-#{template[3]}"
            range = 4
        else
            template = "#{template[1]}-#{template[2]}"
            range = 3
        end

        minicoin_box = yaml["coin"][template]
        next if minicoin_box.nil?

        template_file = coin_template[0]
        (1..range).each do |i|
            if coin_template[i]
                template_file = template_file + "-"
                template_file = template_file + coin_template[i]
            end
        end

        coin_name = "coin-#{template}"
        coin_name = coin_name.gsub("_", ".")
        coin_machine = {}
        coin_machine["name"] = coin_name
        coin_machine["box"] = minicoin_box
        coin_machine["roles"] = [
            {
                "role" => "upload",
                "files" => {
                    "#{ENV['COIN_ROOT']}/provisioning" => "coin/provisioning"
                }
            },
            {
                "role" => "coin-node",
                "template" => template_file,
                "privileged" => false
            }
        ]
        coin_machine["jobs"] = [
            {
                "job" => "build",
                "features" => coin_config["Features"],
                "compiler" => coin_config["Compiler"],
                "configure" => coin_config["Configure arguments"],
                "environment" => coin_config["Environment variables"]
            }
        ]
        coin_machines << coin_machine
    end
    coin_config = {}
    coin_config["machines"] = coin_machines
    return coin_config
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
    machines = load_boxes(yaml, load_coinconfig(yaml))
    machines = load_boxes(yaml, user_yaml)
    machines = load_boxes(yaml, local_yaml)

    merge_roles(machines)

    load_urls(yaml, user_yaml)
    load_urls(yaml, local_yaml)

    $TEST_OUTPUT=yaml
    return machines
end
