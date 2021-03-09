def load_coin(yaml)
    return if ENV['MINICOIN_PROJECT_DIR'].nil?

    coin_machines = []

    return {} if yaml["coin"].nil?
    coin_root = ENV["COIN_ROOT"] || find_config(ENV['MINICOIN_PROJECT_DIR'], "coin")
    while coin_root
        # do we have a project specific config file for coin?
        coin_config_root = "#{coin_root}/coin/platform_configs"
        config_name = File.basename(coin_root)
        if File.exist?("#{coin_config_root}/#{config_name}.yaml")
            coin_config_file = "#{coin_config_root}/#{config_name}.yaml"
        else # if not, use the default for Qt
            coin_config_file = "#{coin_config_root}/qt5.yaml"
        end

        begin
            coin_configs = YAML.load_file(coin_config_file)
            coin_configs = load_includes(coin_configs, coin_config_root)
            coin_configs = coin_configs["Configurations"]
        rescue
            coin_configs = []
        end
        coin_config_index = 0
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
            if minicoin_box.nil?
                STDERR.puts "Warning: No box set for template #{template}"
                next
            end

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
            coin_machine["box"] = minicoin_box["box"]
            coin_machine["roles"] = minicoin_box["roles"] || []
            coin_machine["roles"] += [
                {
                    "role" => "upload",
                    "files" => {
                        "#{coin_root}/coin/provisioning" => "coin/provisioning"
                    }
                },
                {
                    "role" => "coin-node",
                    "template" => template_file,
                    "privileged" => false
                }
            ]
            coin_machine["jobconfigs"] = [
                {
                    "job" => "build",
                    "name" => coin_config["id"] || "#{coin_config['Compiler']}_#{coin_config_index}",
                    "description" => coin_config["Features"].join(";"),
                    "options" => {
                        "features" => coin_config["Features"],
                        "compiler" => coin_config["Compiler"],
                        "configure" => coin_config["Configure arguments"],
                        "environment" => coin_config["Environment variables"]
                    }
                }
            ]
            coin_machines << coin_machine
            coin_config_index += 1
        end
        coin_root = find_config(File.dirname(coin_root), "coin")
    end
    coin_config = {}
    coin_config["machines"] = coin_machines
    return coin_config
end
