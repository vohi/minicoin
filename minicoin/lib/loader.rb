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
            return first + second
        end
        result = first.clone
        result << second
        return result
    end

    if first.is_a?(Hash)
        if second.is_a?(Array)
            puts "Can't insert array #{second} into hash #{first}"
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
        puts "Can't insert value #{second} into hash #{first}"
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
    
    yaml["machines"] = machines
    return machines
end

def load_includes(yaml, basedir)
    includes = yaml["includes"] unless yaml.nil?
    
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
                puts "Error loading file #{include_file}: #{error}"
            end
        end
    end
    
    return yaml
end

def load_minicoin()
    begin # see tests/autotest.rb
        return load_testmachines()["machines"]
    rescue NoMethodError => error # Not running autotest, continue
    rescue => error
        raise
    end
    global_file = File.join($PWD, 'boxes.yml')
    yaml = YAML.load_file(global_file)
    
    user_file = File.join($HOME, 'minicoin/boxes.yml')
    user_yaml = nil
    if File.file?(user_file)
        user_yaml = YAML.load_file(user_file)
    end
    
    yaml = load_includes(yaml, $PWD)
    user_yaml = load_includes(user_yaml, $HOME)
    
    machines = load_boxes(yaml, user_yaml)
    load_settings(yaml, user_yaml)
    load_urls(yaml, user_yaml)
    
    return machines
end