require "open3"

module Minicoin
    module Commands
        class Run < Vagrant.plugin("2", :command)
            def self.synopsis
                "runs a job"
            end

            def self.read_help(path)
                help = {}
                help["summary"] = path
                if File.file?(File.join(path, "help.yml"))
                    help = YAML.load_file(File.join(path, "help.yml"))
                elsif File.file?(File.join(path, "help.txt"))
                    file = File.new(File.join(path, "help.txt"))
                    help["summary"] = file.readline
                end
                help
            end

            def find_jobs()
                def look_up(root)
                    [].tap do |job_roots|
                        while true do
                            job_dir = File.join(root, ".minicoin/jobs")
                            job_roots << job_dir if Dir.exist?(job_dir)
                            old_root = root
                            root = File.dirname(old_root)
                            break if File.identical?(root, old_root)
                        end
                    end
                end
                
                job_roots = [ File.expand_path("jobs") ]
                "#{$HOME}/minicoin/jobs".tap { |user| job_roots << user if File.directory?(user) }
                job_roots += look_up($MINICOIN_PROJECT_DIR || Dir.pwd)
            end
            
            # register a subcommand for every job directory
            def initialize(argv, env)
                @argv, @job_name, @job_args = split_main_and_subcommand(argv)
                super(@argv, env)

                @jobs = {}
                find_jobs().each do |job_root|
                    Dir.entries(job_root).each do |entry|
                        next if [".", ".."].include?(entry)
                        absolute = File.join(job_root, entry)
                        if File.directory?(absolute)
                            @jobs[entry] = absolute
                        end
                    end
                end

                @subcommands = Vagrant::Registry.new

                @jobs.each do |job, _|
                    @subcommands.register(job) do
                        Job
                    end
                end
            end

            def execute
                options = {}
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin run [options] <job> [name|id] [-- extra job args]"
                    option.separator ""
                    option.separator "Available jobs:"
                    
                    @jobs.each do |job, path|
                        help = Run.read_help(path)
                        option.separator "     #{job.ljust(25)}#{help["summary"]}"
                    end
                    
                    option.separator ""
                    option.separator "For help on any individual subcommand run `minicoin run <subcommand> --help`"
                    option.separator ""
                    option.on("--verbose", "Enable verbose output") do |o|
                        options[:verbose] = o
                    end
                    option.on("--privileged", "Run job with administrative privileges") do |o|
                        options[:privileged] = o
                    end
                    option.on("--parallel", "Run the job on several machines in parallel") do |o|
                        options[:privileged] = o
                    end
                end

                argv = parse_options(parser)
                return if !argv
                # argv will be [] but not nil if there's a subcommand

                jobclass = @subcommands.get(@job_name)
                if !@job_name || !jobclass
                    if @job_name && !jobclass
                        @env.ui.error("No such job '#{@job_name}'", prefix: false)
                        @env.ui.error(parser.help, prefix: false)
                    else
                        @env.ui.info(parser.help, prefix: false)
                    end
                    return
                end

                # pass remaining arguments to run through to the job runner
                options[:jobname] = @job_name
                options[:jobpath] = @jobs[@job_name]

                # Initialize and execute the job runner
                jobclass.new(options, @job_args, @env).execute
            end
        end

        class Job < Vagrant.plugin("2", :command)
            def initialize(options, argv, env)
                @run_options = options
                @job_name = @run_options[:jobname]
                @job_path = @run_options[:jobpath]
                super(argv, env)
            end
            
            def synopsis
                @job_path
            end

            def execute()
                job_options = {}
                job_options[:job_args] = []

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin run #{@job_name} [options] [name|id] [-- extra job args]"
                    option.separator ""
                    help = Run.read_help(@job_path)
                    if help
                        option.separator help["summary"]
                        option.separator ""
                    end
                    option.separator "Options:"
                    option.separator ""
                    # read job specific help file and list options
                    if help["options"]
                        help["options"].each do |help_option|
                            var = ""
                            var = help_option["name"].upcase if help_option["type"] == "string"
                            option.on("--#{help_option["name"]} #{var}", help_option["description"]) do |o|
                                @run_options["name"]
                            end
                        end
                    end
                    option.on("--jobconfig JOBCONFIG", "Select a pre-defined job configuration") do |o|
                        puts "Jobconfig specified"
                        @run_options[:jobconfig] = o
                    end
                end

                # everything after the "--" goes to the job script
                split_index = @argv.index("--")
                if split_index
                    job_options[:job_args] = @argv.drop(split_index + 1)
                    @argv = @argv.take(split_index)
                end

                argv = parse_options(parser)
                # this is because our machine matching optimization misinterprets subcommands
                # but running a job on all machines is a bad idea anyway
                return if !argv
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?

                threads = []
                with_target_vms(argv) do |vm|
                    threads << Thread.new do
                        do_execute(vm, job_options)
                    end
                end
                threads.each do |thread|
                    thread.join
                end
            end

            private

            def do_execute(vm, job_options)
                options = job_options.dup
                unless vm.communicate.ready?
                    vm.ui.warn "Machine not ready, trying to bring it up"
                    vm.env.cli("up", vm.name.to_s)
                    if !vm.communicate.wait_for_ready(60)
                        vm.ui.error "Failed to bring up machine"
                        raise Vagrant::Errors::MachineGuestNotReady
                    end
                end

                if vm.guest.name == :windows
                    options[:ext] = "ps1"
                    options[:ext] = "cmd" if File.exist?(File.join(@job_path, "main.cmd"))
                    run_command = "C:\\minicoin\\util\\run_helper.ps1 "
                    # enable verbosity and privileged execution in run_helper
                    run_command += "-verbose " if options[:verbose]
                    run_command += "-privileged " if options[:privileged]
                    target_path = ".minicoin\\jobs"
                    run_command += "Documents\\#{target_path}\\#{@job_name}\\"
                    cleanup_command = "Remove-Item -Force -Recurse #{target_path}\\#{@job_name}"
                else
                    options[:ext] = "sh"
                    run_command = "chmod -R +x .minicoin/jobs && "
                    target_path = ".minicoin/jobs"
                    run_command += "#{target_path}/#{@job_name}/"
                    cleanup_command = "rm -rf #{target_path}/#{@job_name}"
                end
                script_file = "main.#{options[:ext]}"
                if !File.exist?(File.join(@job_path, script_file))
                    @env.ui.error "No script #{script_file} in job directory #{@job_path}"
                    raise Vagrant::Errors::VagrantError.new
                end

                vm.ui.info "Uploading '#{@job_path}'"
                vm.communicate.upload(@job_path, target_path)

                run_local(vm, "pre")

                run_command +=  "#{script_file}"
                job_args = job_arguments(options, vm)
                run_command += " #{job_args.join(" ")}"

                vm.ui.info "Running '#{@job_name}' with arguments #{job_args.join(" ")}"
                process_output = lambda do |type, data|
                    data.rstrip!
                    return if data.nil?
                    data.chomp!
                    if type == :stderr
                        vm.ui.error data
                    else
                        vm.ui.detail data
                    end
                end
                log_verbose(vm.ui, "Executing command '#{run_command}'")
                if vm.guest.name == :windows || !@run_options[:privileged]
                    vm.communicate.execute(run_command, &process_output)
                else
                    vm.communicate.sudo(run_command, &process_output)
                end
                log_verbose(vm.ui, "Cleaning up via '#{cleanup_command}'")
                vm.communicate.sudo(cleanup_command)

                run_local(vm, "post")
            end

            def log_verbose(ui, message)
                return unless @run_options[:verbose]
                ui.warn message
            end

            def run_local(vm, type)
                script = File.join(@job_path, "#{type}-run.sh")
                if File.exist?(script)
                    log_verbose(vm.ui, "Running #{type}-run script for #{@job_name}")
                    stdout, stderr, status = Open3.capture3(script, vm.name.to_s)
                    vm.ui.detail stdout.chomp
                    if status != 0
                        raise StandardError.new "#{pre_script} returned with error code #{status}"
                        vm.ui.error stderr.chomp
                        raise Vagrant::Errors::VagrantError.new
                    end
                end
            end

            def guest_dir(vm, project_dir)
                keys = vm.config.instance_variable_get('@keys')
                minicoin = keys[:minicoin]
                machine = minicoin.machine

                guest_dir = nil
                # check whether we are in a subdirectory of a mapped path, and use the best match
                minicoin.fs_mappings.each do |hostpath, guestpath|
                    hostpath = hostpath.gsub("~", "$HOME")
                    hostpath = expand_env(hostpath, nil)
                    match_length = -1
                    if project_dir.start_with?(hostpath) && hostpath.length > match_length
                        match_length = hostpath.count('/') unless hostpath == ENV["HOME_SHARE"]
                        guest_dir = project_dir.dup #[hostpath.length, -1]
                        guest_dir[hostpath] = guestpath
                    end
                end
                if guest_dir.nil? || guest_dir.empty?
                    vm.ui.warn "the host path '#{project_dir}' doesn't map to any location on the guest:"
                    minicoin.fs_mappings.each do |hostpath, guestpath|
                        vm.ui.warn "    #{hostpath} => #{guestpath}"
                    end
                    guest_dir = project_dir
                end
                guest_dir.gsub!("/", "\\") if vm.guest.name == :windows
                guest_dir
            end

            def job_arguments(options, vm)
                project_dir = $MINICOIN_PROJECT_DIR

                # first guest work dir and host work dir
                arguments = [ guest_dir(vm, project_dir), project_dir ]
                # then the implicit arguments, so that they can be overridden
                arguments += jobconfig(options, vm)
                log_verbose(vm.ui, "Auto-arguments received: #{arguments}")

                # verbosity is passed through to the job, unless the script is a
                # powershell script (then the run_helper has to pass through)
                arguments << "--verbose" if options[:verbose] && options[:ext] != "ps1"

                options[:job_args].each do |job_arg|
                        # powershell job scripts -> single dash
                    job_arg = job_arg[1..-1] if options[:ext] == "ps1" && job_arg.start_with?("--")
                    job_arg = "\"#{job_arg}\"" if job_arg.include?(" ")
                    arguments << job_arg
                end
                arguments
            end

            def jobconfig(options, vm)
                keys = vm.config.instance_variable_get('@keys')
                minicoin = keys[:minicoin]
                machine = minicoin.machine
                return [] if machine["jobconfigs"].nil?

                # enumerate all jobconfigs
                jobconfigs = []
                machine["jobconfigs"].each do |jobconfig|
                    jobconfig["_index"] = jobconfigs.length
                    jobconfigs << jobconfig
                end
                # find the ones that match
                jobconfigs = jobconfigs.select do |jobconfig|
                    res = true
                    res &&= jobconfig["job"] == @job_name
                    res &&= jobconfig["name"] == options[:jobconfig] if options.key?(:jobconfig)
                    res &&= jobconfig["_index"] == options[:index] if options.key?(:index)
                    res
                end
                @logger.debug("#{jobconfigs.count} matching configurations found for job '#{options[:job]}'")
                # print either the configuration, or the tab-separated list of matches
                if jobconfigs.count == 0
                    jobconfig = {}
                elsif jobconfigs.count > 1
                    if @env.ui.is_a?(Vagrant::UI::MachineReadable) || @env.ui.is_a?(Vagrant::UI::NonInteractive)
                        raise Vagrant::Errors::UIExpectsTTY
                    end
                    ui_channel = { :channel => :error }
                    @env.ui.output "Multiple job configurations are available:", ui_channel
                    @env.ui.output "", ui_channel
                    jobconfigs.each do |jobconfig|
                        line = "#{jobconfig['_index']}) #{jobconfig['name']}"
                        line += " - #{jobconfig['description']} " unless jobconfig['description'].nil?
                        @env.ui.output line, ui_channel
                    end
                    @env.ui.output "", ui_channel
                    jobconfig = nil
                    while !jobconfig
                        if @env.ui.stdin.tty?
                            selection = @env.ui.ask "Selection: ", ui_channel
                        else
                            @env.ui.output "Selection: ", ui_channel
                            selection = @env.ui.stdin.gets.chomp
                        end
                        filtered = jobconfigs.select do |jc|
                            jc["_index"].to_s == selection
                        end
                        jobconfig = filtered.first if filtered.count == 1
                        # no point in asking again if the input was piped
                        raise Vagrant::Errors::UIExpectsTTY if !jobconfig && !@env.ui.stdin.tty?
                    end
                    @env.ui.output "Selected: '#{jobconfig['name']}' (run job '#{jobconfig['job']}' with --jobconfig #{jobconfig['name']} to skip this dialog)\n", ui_channel
                else
                    jobconfig = jobconfigs.first
                end
                [].tap do |arguments|
                    jobconfig.each do |key, value|
                        next if key == "name" || key == "job" || key == "description" || key.start_with?("_")
                        if value.is_a?(String)
                            value.gsub!("\\", "\\\\")
                            value.gsub!("\"", "\\\"")
                        end

                        key_flag = "--#{key}"
                        puts options[:job_args]
                        next if options[:job_args].include?(key_flag)
                        arguments << key_flag
                        value = value.join(",") if value.is_a?(Array)
                        if value
                            value = "\"#{value}\"" if value.include?(" ")
                            arguments << value
                        end
                    end
                end
            end
        end
    end
end
