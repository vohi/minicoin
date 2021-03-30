require "open3"
require "vagrant/util/busy"
require "io/console"

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
                ["--repeat", "--jobconfig", "--env"].each do |option|
                    if @argv[-1] == option
                        loop do
                            @argv << @job_name
                            @job_name = @job_args.delete_at(0)
                            break unless @job_name.start_with?("-")
                        end
                    end
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
                options = {
                    env: []
                }
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
                    option.on("--env ENV=VAL", "Specifies comma-separated list of environment variables") do |o|
                        options[:env] += o.split(",")
                    end
                    option.on("--verbose", "Enable verbose output") do |o|
                        options[:verbose] = o
                    end
                    option.on("--privileged", "Run job with elevated privileges") do |o|
                        options[:privileged] = o
                    end
                    option.on("--parallel", "Run the job on several machines in parallel") do |o|
                        options[:parallel] = o
                    end
                    option.on("--repeat COUNT", "Run the job COUNT times, keeping track of results") do |o|
                        begin
                            options[:repeat] = Integer(o)
                        rescue
                            @env.ui.error "Argument error: --repeat COUNT needs to be a number"
                            return 0
                        end
                    end
                    option.on("--fswait", "Wait for file system changes in between repeated") do |o|
                        options[:fswait] = o
                    end
                    option.on("--console", "Run the job as a console session") do |o|
                        options[:console] = o
                    end
                    option.on("--jobconfig JOBCONFIG", "Select a pre-defined job configuration") do |o|
                        options[:jobconfig] = o
                    end
                    option.on("--powershell", "Prefer a powershell main script on Windows guests") do |o|
                        options[:powershell] = o
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
            attr_accessor :tty_width
            def initialize(options, argv, env)
                super(argv, env)
                @run_options = options
                @tty_width = IO.console.winsize[1]
                log_verbose(@env.ui, "Terminal width is #{@tty_width}")
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

            def matchers(vm)
                minicoin = Minicoin.get_config(vm)
                context = Minicoin::Context.new
                context.machine = minicoin.machine

                matcherfile = File.join(@run_options[:jobpath], "matchers.yml")
                matchers = File.exist?(matcherfile) ? YAML.load_file(matcherfile) : {}
                context.preprocess(matchers, "/")
                matchers["matchers"] || []
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
                            var_str = "#{var_tag}"
                            var_str += " #{var}" unless var.nil?
                            option.on(var_str, help_option["description"]) do |o|
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
                return if !argv

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
                        log_verbose(vm.ui, "Waiting for #{vm.name}")
                        wait_for_thread(thread)
                        log_verbose(vm.ui, "Thread with job ID #{thread.job_id} finished")
                        exit_code += thread.exit_code || 128
                    end
                    break if thread.interrupted?
                end
                # wait for all threads (parallel is set)
                if threads.count > 0
                    log_verbose(@env.ui, "Waiting for #{threads.count} jobs to finish")
                    threads.each do |thread|
                        wait_for_thread(thread)
                        exit_code += thread.exit_code || 128
                        thread.exit_code = 0
                    end
                end
                exit_code
            end

            def log_verbose(ui, message)
                return unless @run_options[:verbose]
                ui.warn message
            end

            private

            def wait_for_thread(thread)
                showing_dialog = false
                while thread.alive?
                    if thread.interrupted?
                        thread.kill_job()
                    end
                    if thread.job_status == :waiting && STDIN.tty? && !@run_options[:parallel]
                        command = nil
                        begin
                            Timeout.timeout(1) do
                                if !showing_dialog
                                    @env.ui.detail "Type (q)uit or (w)ake-up and press Enter, or do nothing! ", {new_line: false}
                                    showing_dialog = true
                                end
                                command = STDIN.gets.chomp
                            end
                        rescue Timeout::Error => e
                        end
                        if command
                            case command.downcase
                            when "q", "quit"
                                thread.command!("quit")
                            when "w", "wake", "wakeup", "wake-up"
                                thread.command!("wakeup")
                            end
                        end
                    else
                        showing_dialog = false
                        sleep 1
                    end
                    @tty_width = IO.console.winsize[1]
                end
            end

            class JobThread < Thread
                attr_accessor :vm
                attr_accessor :exit_code
                attr_accessor :pid
                attr_accessor :job
                attr_accessor :job_id
                attr_accessor :job_status
    
                def initialize(job, vm)
                    @job = job
                    @target_path = nil
                    @vm = vm
                    @last_options = {}
                    @pid = nil
                    @interrupt = 0
                    @level = 0
                    @kill_communicator = nil
                    @exit_code = nil
                    @job_id = nil
                    @job_status = :ready
                    super
                end

                def command!(cmd)
                    if @target_path && @kill_communicator
                        @job.log_verbose(@vm.ui, "Waking up job #{@job_id} on #{@vm.name} by touching #{@target_path}/wakeup")
                        begin
                            @kill_communicator.execute("echo \"#{cmd}\" > #{@target_path}/wakeup")
                        rescue => e
                            @vm.ui.error "Error sending command '#{cmd}':"
                            @vm.ui.error e
                        end
                    end
                end
                def kill_job()
                    if @interrupt > @level
                        @level = @interrupt
                        if @guest_os == :windows
                            if @pid # the powershell run_helper needs killing
                                @killcmd = "taskkill /PID #{@pid} /T /F" # works very unreliably without /F
                            else # a task is running
                                @killcmd = "Get-ScheduledTask -TaskPath \"\\minicoin-jobs\\\""
                                if @job_id
                                    @killcmd += "-TaskName \"#{@job_id}\""
                                else
                                    vm.ui.warn "No Job ID received, killing all minicoin jobs"
                                end
                                @killcmd += "| Stop-ScheduledTask"
                            end
                        else
                            signal = @level == 1 ? "SIGTERM" : "SIGKILL"
                            if @pid
                                @killcmd = "setsid kill -#{signal} -- -#{@pid}"
                            else
                                vm.ui.warn "No PID received, killing all bash processes"
                                @killcmd = "setsid killall -#{signal} bash"
                            end
                        end
                        begin
                            vm.ui.warn "Attempting to interrupt process #{@pid || @job_id} running on #{vm.name}"
                            @job.log_verbose(vm.ui, "killing with: '#{@killcmd}")
                
                            begin
                                @kill_communicator.wait_for_ready(5)
                                if @job.run_options[:repeat]
                                    @kill_communicator.sudo(@cleanup_command, { error_check: false })
                                    @job.log_verbose(vm.ui, "Removing job to prevent more runs: '#{@cleanup_command}")
                                end
                                @kill_communicator.sudo(@killcmd, { error_check: false})
                            rescue
                                raise
                            end
                        rescue StandardError => e
                            vm.ui.warn "Received error #{e} when killing job on #{vm.name}"
                        end
                    end
                end

                def interrupted?()
                    @level > 0 || @interrupt > 0
                end
                def interrupt!()
                    @interrupt += 1
                    if @interrupt == 1
                        vm.ui.warn("Interrupt requested, trying to exit")
                    elsif @interrupt == 2
                        vm.ui.warn("Interrupt requested, trying to terminate")
                    else
                        vm.ui.error("Hard exit, process #{@pid} might still be running on #{vm.name}")
                        @exit_code = 255
                        abort
                    end
                end
    
                def do_execute(job_options)
                    @kill_communicator = @vm.communicate.class.new(@vm)
                    @kill_communicator.reset!
                    options = job_options.dup
                    @job_id = sprintf("%20.10f", Time.now.to_f).delete('.').to_i.to_s(36)
                    @job.log_verbose(@vm.ui, "Job ID is #{@job_id}")

                    fswait = nil
                    if @vm.guest.name == :windows
                        @guest_os = :windows
                        options[:ext] = "ps1"
                        options[:ext] = "cmd" if File.exist?(File.join(@job.path, "main.cmd")) && !@job.run_options[:powershell]
                        run_command = "C:\\minicoin\\util\\run_helper.ps1 "
                        run_command += "-jobid #{@job_id} "
                        # enable execution modes through run_helper
                        run_command += "-verbose " if @job.run_options[:verbose]
                        run_command += "-repeat #{@job.run_options[:repeat] || (@job.run_options[:fswait] ? 0 : 1)} "
                        run_command += "-console " if @job.run_options[:console]
                        run_command += "-fswait " if @job.run_options[:fswait]
                        @target_path = ".minicoin\\jobs\\#{@job_id}"
                        run_command += "Documents\\#{@target_path}\\#{@job.name}\\"
                        @cleanup_command = "if ($(Test-Path #{@target_path}\\#{@job.name})) { Remove-Item -Force -Recurse #{@target_path} | Out-Null }"
                    else
                        options[:ext] = "sh"
                        @target_path = ".minicoin/jobs/#{@job_id}"
                        run_command = "#{@target_path}/#{@job.name}/"
                        @cleanup_command = "rm -rf #{@target_path}"
                        if @job.run_options[:fswait]
                            if @vm.guest.name == :darwin
                                fswait_cmd = "fswatch -1 -r"
                            else
                                fswait_cmd = "inotifywait -qq -r --event modify,attrib,close_write,move,create,delete"
                            end
                            fswait = <<-BASH
                                >&2 echo "minicoin.process.wait"
                                echo "($(date '%{date_format}')) Waiting for file system changes in %{fswait_path}"
                                #{fswait_cmd} #{@target_path} %{fswait_path}
                                if [ -f "#{@target_path}/wakeup" ]
                                then
                                    cmd=`tail -n1 #{@target_path}/wakeup`
                                    rm -f "#{@target_path}/wakeup"
                                    [ "$cmd" == "quit" ] && break
                                fi
                                BASH
                        end
                    end
                    script_file = "main.#{options[:ext]}"
                    if !File.exist?(File.join(@job.path, script_file))
                        @env.ui.error "No script #{script_file} in job directory #{@job.path}"
                        raise Vagrant::Errors::VagrantError.new
                    end

                    begin
                        run_local("pre")
                    rescue Minicoin::Errors::PreRunFail => e
                        @vm.ui.error "#{e}"
                        return false
                    end

                    @vm.ui.info "Uploading '#{@job.path}'"
                    @vm.communicate.upload(@job.path, @target_path)

                    run_command +=  "#{script_file}"
                    job_config = jobconfig(options)
                    @job_args = job_arguments(options, job_config)

                    if options[:ext] == "sh"
                        run_command += " #{@job_args.join(" ")}"
                        fswait = fswait % { fswait_path: @job_args.first, date_format: "+%H:%M:%S" } if @job.run_options[:fswait]

                        envelope = <<-BASH
                            PID=$$
                            export DISPLAY=:0
                            chmod -R +x .minicoin/jobs
                            PGID=$(($(ps -o pgid= $PID)))
                            >&2 echo "minicoin.process.id=$PGID"
                        BASH
                        @job.run_options[:env].each do |env|
                            md = /([A-Za-z0-9]+[\+]?)=(.*)/.match(env)
                            key = md[1]
                            value = md[2]
                            if key.end_with?('+')
                                key = key[0..-2]
                                value="#{value}:$#{key}"
                            end
                            envelope += "export #{key}=\"#{value}\"\n"
                        end
                        if @job.run_options[:repeat] || @job.run_options[:fswait]
                            envelope += <<-BASH
                                repeat=#{@job.run_options[:repeat] || "0"}
                                success=0
                                total=0
                                while true
                                do
                                    >&2 echo "minicoin.process.run"
                                    #{run_command}
                                    exit_code=$?
                                    if [ $exit_code -eq 0 ]
                                    then
                                        success=$(( $success + 1 ))
                                        out=1
                                    else
                                        out=2
                                    fi
                                    total=$(( $total + 1 ))
                                    >&${out} echo "Run $total/$repeat: Exit code $exit_code"
                                    [[ $repeat -gt 0 && $total -ge $repeat ]] && break
                                    #{fswait}
                                done
                                [ $success -lt $total ] && out=2 || out=1
                                >&${out} echo "Success rate is ${success}/${total}"
                                [ $total -gt 1 ] && exit_code=$(( $total - $success ))
                                exit $exit_code
                            BASH
                            run_command = envelope
                        else
                            run_command = envelope + "\n" + run_command
                        end
                    else
                        run_command += " -jobargs @('#{@job_args.join("', '")}')"
                        run_command += " -envvars @('#{@job.run_options[:env].join("', '")}')" if @job.run_options[:env].count > 0
                    end

                    @vm.ui.info "Running '#{@job.name}' with arguments #{@job_args.join(" ")}"

                    matchers = job_config["matchers"] || []
                    matchers += @job.matchers(@vm)
                    matchers.each do |matcher|
                        begin
                            matcher[:regexp] =  Regexp.new(matcher["pattern"])
                        rescue RegexpError => e
                            vm.ui.warn "#{matcher["pattern"]} is not a valid regular expression: #{e}"
                            next
                        end
                        matcher[:options] = {}.tap do |options|
                            options[:suppress] = matcher["suppress"] == true
                            options[:color] = matcher["color"].to_sym if matcher["color"]
                            options[:new_line] = matcher["newline"] != false
                            options[:bold] = matcher["bold"] == true
                            options[:replace] = matcher["replace"] == true
                            options[:channel] = matcher["error"] ? :error : :detail
                            options[:continue] = matcher["continue"] == true
                        end
                    end

                    @buffer = []
                    @job.log_verbose(@vm.ui, "Executing command '#{run_command}'")
                    Vagrant::Util::Busy.busy(Proc.new{ interrupt!() }) do
                        begin
                            opts = {
                                error_check: false,
                                sudo: @job.run_options[:privileged]
                            }
                            @exit_code = @vm.communicate.execute(run_command, opts) do |type, data|
                                process_output(matchers, type, data)
                            end
                        rescue StandardError => e
                            @job.log_verbose(@vm.ui, "Received error from command:")
                            @job.log_verbose(@vm.ui, e)
                        end
                    end
                    if interrupted?()
                        @buffer.each do |entry|
                            echo(entry[0], entry[1])
                        end
                        @vm.ui.warn "Job exited after interruption"
                        @exit_code = 130
                    elsif @exit_code != 0
                        @vm.ui.error "Job finished with non-zero exit code #{@exit_code}"
                    end
                    begin
                        @job.log_verbose(vm.ui, "Cleaning up via '#{@cleanup_command}'")
                        @vm.communicate.sudo(@cleanup_command, { error_check: false, sudo: true }) do |type, data|
                            @job.log_verbose(vm.ui, data)
                        end
                    rescue => e
                        @job.log_verbose(vm.ui, "Error cleaning up: #{e}")
                    end

                    begin
                        run_local("post")
                    rescue Minicoin::Errors::PostRunFail => e
                        @vm.ui.error "#{e}"
                    end
                    @exit_code
                end

                def process_output(matchers, type, data)
                    data.rstrip!
                    return if data.nil?
                    data.chomp!
                    data.split("\n").each do |line|
                        if type == :stderr && line.start_with?("minicoin.process.")
                            md = /minicoin\.process\.(?<var>[a-z]+)=?(?<val>.*)?/.match(line)
                            case md[:var]
                            when "id"
                                @pid = md[:val]
                                @pid = nil if @pid && @pid.empty?
                                @job.log_verbose(@vm.ui, "Job #{@job_id} has process ID #{@pid} on guest")
                            when "wait"
                                @job.log_verbose(@vm.ui, "Job #{@job_id} is about to wait")
                                @job_status = :waiting
                            when "run"
                                @job.log_verbose(@vm.ui, "Job #{@job_id} is running")
                                @job_status = :running
                            else
                                @job.log_verbose(@vm.ui, "Job #{@job_id} sent status info '#{data}'")
                            end
                            next
                        end
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
                                    if options[:replace]
                                        line.gsub!(@job_args[0], @job_args[1])
                                        if @guest_os == :windows && !Vagrant::Util::Platform.windows?
                                            line.gsub!("\\", "/")
                                        elsif @guest_os != :windows && Vagrant::Util::Platform.windows?
                                            line.gsub!("/", "\\")
                                        end
                                    end
                                    break # first matcher wins
                                end
                            end
                        else # all stderr goes to the error channel
                            options[:channel] = :stderr
                        end
                        break if options[:suppress]

                        # batch data up
                        if interrupted?()
                            @job.log_verbose(@vm.ui, line)
                            @buffer << [ line, options ]
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
                        @vm.ui.detail "", **{prefix: false, newline: true} if @last_options[:new_line] == false && (options[:new_line].nil? || options[:new_line] == true)
                    end
                    if @job.tty_width && options[:new_line] == false && data.length > @job.tty_width
                        data = "#{data[0..@job.tty_width - 4]}..."
                    end
                    if options[:color].nil?
                        options[:color] = :red if options[:channel] == :error
                    end
                    if options[:channel] == :stderr
                        @vm.ui.error(data, **options)
                    else
                        @vm.ui.detail(data, **options)
                    end
                    @last_options = options
                rescue => e
                    STDERR.puts "Internal error: #{e}"
                end

                def run_local(type)
                    begin
                        require "#{@job.path}/#{type}-run"
                        @job.log_verbose(@vm.ui, "Running #{type}-run ruby script for #{@job.name}")
                        eval("#{@job.name.gsub("-", "_").capitalize}::#{type}_run(@vm)")
                    rescue LoadError => e
                    end
                    ext = Vagrant::Util::Platform.windows? ? "cmd" : "sh"
                    script = File.join(@job.path, "#{type}-run.#{ext}")
                    if File.exist?(script)
                        @job.log_verbose(@vm.ui, "Running #{type}-run script for #{@job.name}")
                        stdout, stderr, status = Open3.capture3(script, @vm.name.to_s)
                        @vm.ui.detail stdout.chomp
                        raise Minicoin::Errors::PreRunFail.new("#{pre_script} returned with error code #{status}:\n#{stderr}") if status != 0
                    end
                end

                def guest_dir(project_dir)
                    minicoin = Minicoin.get_config(@vm)
                    machine = minicoin.machine

                    guest_dir = nil
                    # check whether we are in a subdirectory of a mapped path, and use the best match
                    minicoin.fs_mappings.each do |hostpath, guestpath|
                        hostpath = hostpath.gsub("~", "$HOME")
                        hostpath = expand_env(hostpath)
                        match_length = -1
                        if project_dir.start_with?(hostpath) && hostpath.length > match_length
                            match_length = hostpath.count('/') unless hostpath == ENV["HOME_SHARE"]
                            guest_dir = project_dir.dup #[hostpath.length, -1]
                            guest_dir[hostpath] = guestpath
                        end
                    end
                    guest_dir ||= ""
                    if guest_dir.empty?
                        @vm.ui.warn "The host path '#{project_dir}' doesn't map to any location on the guest:"
                        minicoin.fs_mappings.each do |hostpath, guestpath|
                            hostpath = $PWD if hostpath == "."
                            @vm.ui.warn "    #{hostpath} => #{guestpath}"
                        end
                        guest_dir = project_dir
                    end
                    guest_dir = guest_dir.gsub("/", "\\") if @vm.guest.name == :windows
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
                        res &&= jc["job"] == @job.run_options[:jobname]
                        res &&= jc["name"] == @job.run_options[:jobconfig] if @job.run_options.key?(:jobconfig)
                        res &&= jc[:_index] == @job.run_options[:jobconfig_index] if @job.run_options.key?(:jobconfig_index)
                        default_config = jc if res && jc["default"]
                        res
                    end
                    @job.log_verbose(@vm.ui, "Candidates: #{jobconfigs}")
                    
                    if jobconfigs.count == 0
                        jobconfig = {}
                    elsif default_config
                        jobconfig = default_config
                    elsif jobconfigs.count > 1
                        # start dialog if multiple configurations, otherwise 
                        @job.log_verbose(@vm.ui, "#{jobconfigs.count} matching configurations found for job '#{name()}'")
                        if Vagrant.version?(">= 2.2.14")
                            if @vm.ui.is_a?(Vagrant::UI::MachineReadable) || @vm.ui.is_a?(Vagrant::UI::NonInteractive)
                                raise Vagrant::Errors::UIExpectsTTY
                            end
                        end
                        ui_channel = { channel: :error }
                        ui_channel[:prefix] = @job.run_options[:machine_ui]
                        @vm.ui.output "Multiple job configurations are available:", **ui_channel
                        @vm.ui.detail "", **ui_channel
                        jobconfigs.each do |jobconfig|
                            line = "#{jobconfig[:_index]}) #{jobconfig['name']}"
                            line += " - #{jobconfig['description']} " unless jobconfig['description'].nil?
                            @vm.ui.detail line, **ui_channel
                        end
                        @vm.ui.detail "", **ui_channel
                        jobconfig = nil
                        while !jobconfig
                            if @vm.ui.stdin.tty?
                                selection = @vm.ui.ask "Selection: ", **ui_channel.merge({bold: true})
                            else
                                @vm.ui.output "Selection: ", **ui_channel
                                selection = @vm.ui.stdin.gets.chomp
                            end
                            filtered = jobconfigs.select do |jc|
                                jc[:_index].to_s == selection
                            end
                            jobconfig = filtered.first if filtered.count == 1
                            # no point in asking again if the input was piped
                            raise Vagrant::Errors::UIExpectsTTY if !jobconfig && !@vm.ui.stdin.tty?
                        end
                        @vm.ui.info "Selected: '#{jobconfig['name']}' (run job '#{jobconfig['job']}' with '--jobconfig #{jobconfig['name']}' to skip this dialog)\n", **ui_channel
                    else
                        jobconfig = jobconfigs.first
                    end
                    jobconfig
                end
            end
        end
    end
end
