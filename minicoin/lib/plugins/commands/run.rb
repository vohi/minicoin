require "open3"
require "vagrant/util/busy"

module Minicoin
    module Commands
        class Run < Vagrant.plugin("2", :command)
            def self.synopsis
                "runs a job"
            end

            def self.read_help(path)
                help = {}
                if File.file?(File.join(path, "help.yml"))
                    help = YAML.load_file(File.join(path, "help.yml"))
                elsif File.file?(File.join(path, "help.txt"))
                    options = []
                    current = nil
                    File.open(File.join(path, "help.txt")).each do |line|
                        # first non-empty line is the summary
                        if help["summary"].nil?
                            help["summary"] = line
                            next
                        end
                        # any line starting with -- creates a new option
                        if line.start_with?("--")
                            current = {}
                            current["name"], varname = line.delete_prefix("--").split(" ")
                            current["type"] = "string" unless varname.nil?
                            options << current
                            next
                        elsif current.nil?
                            # everything else before the first option is job description
                            line.lstrip! unless line.lstrip.empty?
                            help["description"] = (help["description"] || "") + line
                            next
                        end

                        # ignore empty lines
                        next if line.strip.empty?
                        # next line after -- is the description

                        current["description"] = line if current && current["description"].nil?
                    end
                    help["options"] = options
                end
                help["summary"] = "[no help found at #{path}]" if help["summary"].nil?
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
                # special case, since we have a main command argument that takes a value
                if @argv[-1] == "--jobconfig"
                    @argv << @job_name
                    @job_name = @job_args.delete_at(0)
                end
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
                    option.separator ""
                    
                    @jobs.each do |job, path|
                        help = Run.read_help(path)
                        option.separator "     #{job.ljust(25)}#{help["summary"]}"
                    end
                    
                    option.separator ""
                    option.separator "For help on a job run `minicoin run <job> --help`"
                    option.separator ""
                    option.on("--verbose", "Enable verbose output") do |o|
                        options[:verbose] = o
                    end
                    option.on("--privileged", "Run job with elevated privileges") do |o|
                        options[:privileged] = o
                    end
                    option.on("--parallel", "Run the job on several machines in parallel") do |o|
                        options[:parallel] = o
                    end
                    option.on("--jobconfig JOBCONFIG", "Select a pre-defined job configuration") do |o|
                        options[:jobconfig] = o
                    end

                    option.separator ""
                    option.separator "Standard options:"
                    option.separator ""
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
                super(argv, env)
            end
            
            def path
                @run_options[:jobpath]
            end
            def name
                @run_options[:jobname]
            end
            def run_options
                @run_options
            end
            
            def synopsis
                path()
            end

            def execute()
                job_options = {}
                job_options[:job_args] = []

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin run #{name()} [options] [name|id] [-- extra job args]"
                    option.separator ""
                    help = Run.read_help(path())
                    if help
                        option.separator help["summary"]
                        option.separator ""
                        option.separator help["description"]
                        option.separator ""
                    end
                    # read job specific help file and list options
                    if help["options"]
                        option.separator "Options:"
                        option.separator ""
                        help["options"].each do |help_option|
                            var = help_option["name"].upcase if help_option["type"] == "string"
                            var_tag = "--#{help_option["name"]}"
                            option.on("#{var_tag} #{var}", help_option["description"]) do |o|
                                job_options[:job_args] << var_tag
                                job_options[:job_args] << o unless var.nil?
                            end
                        end
                        option.separator ""
                    end
                    option.separator "Standard options:"
                    option.separator ""
                end

                # everything after the "--" goes to the job script
                split_index = @argv.index("--")
                if split_index
                    job_options[:job_args] << @argv.drop(split_index + 1)
                    job_options[:job_args].flatten!
                    @argv = @argv.take(split_index)
                end

                argv = parse_options(parser)
                # this is because our machine matching optimization misinterprets subcommands
                # but running a job on all machines is a bad idea anyway
                return if !argv
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?

                @run_options[:machine_ui] = argv.count > 1 && @run_options[:parallel]
                Thread.report_on_exception = true
                threads = []
                exit_code = 0
                with_target_vms(argv) do |vm|
                    unless vm.communicate.ready?
                        vm.ui.warn "Machine not ready, trying to bring it up"
                        vm.env.cli("up", vm.name.to_s)
                        if !vm.communicate.wait_for_ready(60)
                            vm.ui.error "Failed to bring up machine"
                            raise Vagrant::Errors::MachineGuestNotReady
                        end
                    end
    
                    log_verbose(vm.ui, "Starting job on #{vm.name}")
                    thread = JobThread.new(self, vm) do
                        Thread.current.do_execute(job_options)
                    end
                    thread.run
                    if @run_options[:parallel]
                        threads << thread
                    else
                        log_verbose(vm.ui, "Waiting for #{vm.name} #{thread.status}")
                        while thread.alive?
                            thread.check_interrupted()
                        end
                        log_verbose(vm.ui, "Ending thread")
                        thread.join
                        exit_code += thread.exit_code
                    end
                    break if thread.interrupted?
                end
                # wait for all threads (parallel is set)
                if threads.count > 0
                    log_verbose(@env.ui, "Waiting for #{threads.count} jobs to finish")
                    any_alive = true
                    while any_alive
                        any_alive = false
                        threads.each do |thread|
                            if thread.alive?
                                thread.check_interrupted()
                                any_alive = true
                            else
                                thread.join
                                exit_code += thread.exit_code
                                thread.exit_code = 0
                            end
                        end
                    end
                end
                exit_code
            end

            def log_verbose(ui, message)
                return unless @run_options[:verbose]
                ui.warn message
            end

            private

            class JobThread < Thread
                attr_accessor :vm
                attr_accessor :exit_code
                attr_accessor :job
    
                def initialize(job, vm)
                    @job = job
                    @vm = vm
                    @last_options = {}
                    @pid = nil
                    @interrupt = 0
                    @level = 0
                    @exit_code = 0
                    super
                end
    
                def interrupt!()
                    @interrupt += 1
                    if @interrupt == 1
                        vm.ui.warn("Interrupt requested, trying to exit")
                    elsif @interrupt == 2
                        vm.ui.warn("Interrupt requested, trying to terminate")
                    else
                        vm.ui.error("Hard exit, process #{@pid} might still be running on #{vm.name}")
                        @exit_code=255
                        exit
                    end
                end
                def interrupted?()
                    @level > 0 || @interrupt > 0
                end
                def pid()
                    @pid
                end
                def pid=(id)
                    @pid = id
                end
    
                def check_interrupted()
                    sleep 1
                    if @interrupt > @level && @pid
                        vm.ui.warn "Attempting to interrupt job #{@pid} running on #{vm.name}"
                        @level = @interrupt
                        begin
                            opts = {
                                error_check: false,
                                sudo: true
                            }
                            if vm.guest.name == :windows
                                killcmd = "psexec -i 1 -u vagrant -p vagrant taskkill /PID #{@pid}"
                                if @level > 1
                                    killcmd += " /F"
                                end
                                killcmd += "; taskkill /PID #{@pid}"
                                if @level > 1
                                    killcmd += " /F"
                                end
                            else
                                if @level == 1
                                    killcmd = "kill -SIGTERM #{@pid}"
                                else
                                    killcmd = "kill -SIGKILL #{@pid}"
                                end
                            end
                            vm.ui.warn "Sending kill signal to process"
                            vm.communicate.sudo(killcmd, opts)
                        rescue StandardError => e
                            vm.ui.warn "Received error #{e} when killing job on #{vm.name}"
                        end
                    end
                end
    
                def do_execute(job_options)
                    options = job_options.dup

                    if @vm.guest.name == :windows
                        options[:ext] = "ps1"
                        options[:ext] = "cmd" if File.exist?(File.join(@job.path, "main.cmd"))
                        run_command = "C:\\minicoin\\util\\run_helper.ps1 "
                        # enable verbosity and privileged execution in run_helper
                        run_command += "-verbose " if @job.run_options[:verbose]
                        run_command += "-privileged " if @job.run_options[:privileged]
                        target_path = ".minicoin\\jobs"
                        run_command += "Documents\\#{target_path}\\#{@job.name}\\"
                        cleanup_command = "Remove-Item -Force -Recurse #{target_path}\\#{@job.name}"
                    else
                        options[:ext] = "sh"
                        run_command = "chmod -R +x .minicoin/jobs && "
                        target_path = ".minicoin/jobs"
                        run_command += "#{target_path}/#{@job.name}/"
                        cleanup_command = "rm -rf #{target_path}/#{@job.name}"
                    end
                    script_file = "main.#{options[:ext]}"
                    if !File.exist?(File.join(@job.path, script_file))
                        @env.ui.error "No script #{script_file} in job directory #{@job.path}"
                        raise Vagrant::Errors::VagrantError.new
                    end

                    @vm.ui.info "Uploading '#{@job.path}'"
                    @vm.communicate.upload(@job.path, target_path)

                    run_local("pre")

                    run_command +=  "#{script_file}"
                    job_config = jobconfig(options)
                    @job_args = job_arguments(options, job_config)
                    run_command += " #{@job_args.join(" ")}"

                    @vm.ui.info "Running '#{@job.name}' with arguments #{@job_args.join(" ")}"

                    matchers = job_config["matchers"] || []
                    matchers.each do |matcher|
                        begin
                            re = Regexp.new(matcher["pattern"])
                        rescue RegexpError => e
                            vm.ui.warn "#{matcher["pattern"]} is not a valid regular expression: #{e}"
                            next
                        end
                        matcher[:regexp] = re
                        matcher[:options] = {}.tap do |options|
                            options[:color] = matcher["color"].to_sym if matcher["color"]
                            options[:new_line] = matcher["newline"] ? !!matcher["newline"] : true
                            options[:bold] = matcher["bold"] ? !!matcher["bold"] : false
                            options[:replace] = !!matcher["replace"]
                            options[:channel] = matcher["error"] ? :error : :detail
                        end
                    end

                    @buffer = []
                    @job.log_verbose(@vm.ui, "Executing command '#{run_command}'")
                    Vagrant::Util::Busy.busy(Proc.new{ thread.interrupt! }) do
                        begin
                            opts = {
                                error_check: false,
                                sudo: @vm.guest.name != :windows && @job.run_options[:privileged]
                            }
                            @exit_code = @vm.communicate.execute(run_command, opts) do |type, data|
                                process_output(matchers, type, data)
                            end
                        rescue StandardError => e
                            @job.log_verbose(@vm.ui, "Received error from command:")
                            @job.log_verbose(@vm.ui, e)
                            raise e
                        end
                    end
                    if interrupted?()
                        buffer.each do |entry|
                            echo(entry[0], entry[1])
                        end
                        @vm.ui.warn "Job exited after interruption"
                    end
                    if @exit_code != 0
                        @vm.ui.error "Job finished with non-zero exit code #{@exit_code}"
                    end
                    @job.log_verbose(vm.ui, "Cleaning up via '#{cleanup_command}'")
                    @vm.communicate.sudo(cleanup_command)

                    run_local("post")
                    @exit_code
                end

                def process_output(matchers, type, data)
                    data.rstrip!
                    return if data.nil?
                    data.chomp!
                    if !@pid && data.start_with?("minicoin.process.id=")
                        @pid = data.delete_prefix("minicoin.process.id=")
                        @job.log_verbose(@vm.ui, "Job has process ID #{@pid} on guest")
                        return
                    end
                    data.split("\n").each do |line|
                        options = {}
                        if type == :stdout
                            matchers.each do |matcher|
                                if matcher[:regexp] && matcher[:regexp].match?(line)
                                    if matcher["continue"]
                                        options = @last_options
                                    else
                                        options = matcher[:options]
                                    end
                                    # s/guest_dir/host_dir
                                    line.gsub!(@job_args[0], @job_args[1]) if options[:replace]
                                    break # first matcher wins
                                end
                            end
                        else # all stderr goes to the error channel
                            options[:channel] = :stderr
                        end

                        # batch data up
                        if interrupted?()
                            buffer << [ line, options ]
                        else
                            echo(line, options)
                        end
                    end
                end

                def echo(data, options={})
                    if @job.run_options[:machine_ui] # if we need per-machine output, then we can't skip newlines
                        options[:prefix] = true
                        options[:new_line] = true
                    else
                        options[:prefix] = false
                        @vm.ui.clear_line if @last_options[:new_line] == false && options[:new_line] == false
                        @vm.ui.detail "", { prefix: false, newline: true } if @last_options[:new_line] == false && (options[:new_line].nil? || options[:new_line] == true)
                    end
                    if options[:color].nil?
                        options[:color] = :red if options[:channel] == :error
                    end
                    if options[:channel] == :stderr
                        @vm.ui.error(data, options)
                    else
                        @vm.ui.detail(data, options)
                    end
                    @last_options = options
                end

                def run_local(type)
                    script = File.join(@job.path, "#{type}-run.sh")
                    if File.exist?(script)
                        @job.log_verbose(@vm.ui, "Running #{type}-run script for #{@job.name}")
                        stdout, stderr, status = Open3.capture3(script, @vm.name.to_s)
                        @vm.ui.detail stdout.chomp
                        if status != 0
                            raise StandardError.new "#{pre_script} returned with error code #{status}"
                            @vm.ui.error stderr.chomp
                            raise Vagrant::Errors::VagrantError.new
                        end
                    end
                end

                def guest_dir(project_dir)
                    minicoin = Minicoin.get_config(@vm)
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
                        @vm.ui.warn "the host path '#{project_dir}' doesn't map to any location on the guest:"
                        minicoin.fs_mappings.each do |hostpath, guestpath|
                            @vm.ui.warn "    #{hostpath} => #{guestpath}"
                        end
                        guest_dir = project_dir
                    end
                    guest_dir.gsub!("/", "\\") if @vm.guest.name == :windows
                    guest_dir
                end

                def job_arguments(options, job_config)
                    project_dir = $MINICOIN_PROJECT_DIR

                    # first guest work dir and host work dir
                    arguments = [ guest_dir(project_dir), project_dir ]
                    # then the implicit arguments, so that they can be overridden
                    auto_args = job_config["options"] || []
                    auto_args.each do |key, value|
                        next if value == false # boolean flag that should not be set
                        value = value.join(",") if value.is_a?(Array)
                        value = value.to_s
                        value.gsub!("\\", "\\\\")
                        value.gsub!("\"", "\\\"")

                        key_flag = "--#{key}"
                        # already set by user
                        next if options[:job_args].include?(key_flag)
                        arguments << key_flag
                        if value
                            value = "\"#{value}\"" if value.include?(" ")
                            arguments << value
                        end
                    end
                    @job.log_verbose(@vm.ui, "Auto-arguments received: #{arguments}")

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

                def jobconfig(options)
                    minicoin = Minicoin.get_config(@vm)
                    machine = minicoin.machine
                    return {} if machine["jobconfigs"].nil?

                    # enumerate all jobconfigs
                    jobconfigs = []
                    machine["jobconfigs"].each do |jobconfig|
                        jobconfig[:_index] = jobconfigs.length
                        jobconfigs << jobconfig
                    end
                    begin
                        @job.run_options[:jobconfig_index] = Integer(@job.run_options[:jobconfig])
                        @job.run_options.delete(:jobconfig)
                    rescue
                        # not an integer
                    end
                    # find the ones that match, remember the default
                    @job.log_verbose(@vm.ui, "Finding jobconfig matching #{@job.run_options}")
                    default_config = nil
                    jobconfigs = jobconfigs.select do |jc|
                        res = true
                        res &&= jc["job"] == @job.name
                        res &&= jc["name"] == @job.run_options[:jobconfig] if @job.run_options.key?(:jobconfig)
                        res &&= jc[:_index] == @job.run_options[:jobconfig_index] if @job.run_options.key?(:jobconfig_index)
                        default_config = jc if res && jc["default"]
                        res
                    end
                    
                    if jobconfigs.count == 0
                        jobconfig = {}
                    elsif default_config
                        jobconfig = default_config
                    elsif jobconfigs.count > 1
                        # start dialog if multiple configurations, otherwise 
                        @job.log_verbose(@vm.ui, "#{jobconfigs.count} matching configurations found for job '#{name()}'")
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
                                jc[:_index].to_s == selection
                            end
                            jobconfig = filtered.first if filtered.count == 1
                            # no point in asking again if the input was piped
                            raise Vagrant::Errors::UIExpectsTTY if !jobconfig && !@env.ui.stdin.tty?
                        end
                        @env.ui.output "Selected: '#{jobconfig['name']}' (run job '#{jobconfig['job']}' with --jobconfig #{jobconfig['name']} to skip this dialog)\n", ui_channel
                    else
                        jobconfig = jobconfigs.first
                    end
                    jobconfig
                end
            end
        end
    end
end
