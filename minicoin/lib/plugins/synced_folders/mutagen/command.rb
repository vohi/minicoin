module Minicoin
    module SyncedFolderMutagen
        class Command < Vagrant.plugin("2", :command)
            def self.synopsis
                "manage mutagen syncs to minicoin machines"
            end

            def initialize(argv, env)
                @argv, @sub, @sub_args = split_main_and_subcommand(argv)
                super(@argv, env)

                @subcommands = Vagrant::Registry.new
                @subcommands.register(:create) do
                    Create
                end
                @subcommands.register(:terminate) do
                    Terminate
                end
                @subcommands.register(:pause) do
                    Pause
                end
                @subcommands.register(:resume) do
                    Resume
                end
                @subcommands.register(:list) do
                    List
                end
                @subcommands.register(:wait) do
                    Wait
                end
            end

            def execute()
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin mutagen <subcommand> [name|id]"
                    option.separator ""
                    option.separator "Available subcommands:"
                    option.separator ""
                    @subcommands.each do |key, klass|
                        option.separator "     #{key.to_s.ljust(31)} #{klass.synopsis}"
                    end
                    option.separator ""
                    option.separator "For help with any individual subcommand run `minicoin mutagen <subcommand> -h"
                    option.separator ""
                end

                argv = parse_options(parser)
                return if !argv
                # argv will be [] but not nil if there's a subcommand

                command_class = @subcommands.get(@sub.to_sym) if @sub
                return @env.ui.info(parser.help) if !command_class || !@sub
                command_class.new(@sub_args, @env).execute
            end
        end

        class Create < Vagrant.plugin("2", :command)
            def self.synopsis
                "creates a sync session to the machine"
            end
            def execute()
                options = {}
                options[:switches] = ["--ignore-vcs"]
                options[:ignore] = []
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin mutagen create [options] <alpha> [name|id]"
                    option.separator ""
                    option.on("--name NAME", "Specify the session name") do |o|
                        options[:name] = o
                    end
                    option.on("--sync-mode MODE", "Specifies the sync mode") do |o|
                        options[:sync_mode] = o
                    end
                    option.on("--ignore PATHS", "Specify ignore paths") do |o|
                        options[:ignore] << o
                    end
                    option.on("--no-ignore-vcs", "Propagate VCS directories") do |o|
                        options[:switches].delete("--ignore-vcs")
                        options[:switches] << "--no-ignore-vcs"
                    end
                end

                split_index = @argv.index("--")
                if split_index
                    passthrough = @argv.drop(split_index + 1).join(" ")
                    @argv = @argv.take(split_index)
                end

                argv = parse_options(parser)
                return if !argv
                alpha = File.expand_path(argv.first)
                beta = alpha.gsub(Dir.home, "")[1..-1]
                argv = argv.drop(1)

                opt_str = " --name #{options[:name] || "minicoin"}"
                opt_str += " --sync-mode #{options[:sync_mode] || "one-way-replica"}"
                (options[:ignore] || []).each do |ignore|
                    opt_str += " --ignore #{ignore}"
                end
                opt_str += " #{options[:switches].join(" ")}"
                opt_str += " #{passthrough}"

                with_target_vms(argv) do |vm|
                    raise Vagrant::Errors::MachineGuestNotReady if !vm.ssh_info
                    sessions = SyncedFolderMutagen.parse_sessions(vm)
                    SyncedFolderMutagen.upload_key(vm) if sessions.empty?

                    dirname = File.dirname(beta)
                    dirname = "../#{dirname}" if vm.guest.name == :windows

                    vm.communicate.execute("mkdir -p #{dirname}") do |type, data|
                        vm.ui.error data.strip if type == :stderr
                    end

                    opt_str += " --label minicoin=#{vm.name}"
                    beta_str = "#{vm.ssh_info[:username]}@#{vm.ssh_info[:host]}:#{vm.ssh_info[:port]}:#{beta}"

                    stdout, stderr, status = Open3.capture3("echo yes | #{SyncedFolderMutagen.mutagen_path} sync create #{opt_str} #{alpha} #{beta_str}")
                    if status != 0
                        vm.ui.error stderr.strip
                    end
                end
            end
        end
        class Terminate < Vagrant.plugin("2", :command)
            def self.synopsis
                "terminates a sync session"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.on("--all", "Terminate all sessions for the specified machines") do |o|
                        options[:all] = o
                    end
                    option.on("--alpha PATH", "Stop syncing matching paths") do |o|
                        options[:alpha] = o
                    end
                end

                argv = parse_options(parser)
                return if !argv
                raise Minicoin::Errors::MissingArgument.new("Neither --alpha nor --all specified") if !options[:all] && !options[:alpha]

                with_target_vms(argv) do |vm|
                    if options[:all]
                        stdout, stderr, status = SyncedFolderMutagen.call_mutagen("terminate", vm.name)
                        vm.ui.error stderr.strip if status != 0
                        vm.ui.detail stdout unless stdout.empty?
                    else
                        sessions = SyncedFolderMutagen.parse_sessions(vm)
                        found = false
                        sessions.each do |session|
                            if /#{options[:alpha]}/.match?(session["Alpha"]["URL"])
                                found = true
                                stdout, stderr, status = SyncedFolderMutagen.call_mutagen("terminate", nil, session["Identifier"])
                                vm.ui.error stderr.strip if status != 0
                                stdout.strip!
                                vm.ui.detail stdout unless stdout.empty?
                            end
                        end
                        vm.ui.warn "No matching session found" unless found
                    end
                    sessions = SyncedFolderMutagen.parse_sessions(vm)
                    if sessions.empty?
                        vm.ui.warn "Last session to #{vm.name} terminated, removing from list of known hosts"
                        SyncedFolderMutagen.revoke_trust(vm, force: true)
                    end
                end
            end
        end

        class Pause < Vagrant.plugin("2", :command)
            def self.synopsis
                "pauses all sync sessions to the machine"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    stdout, stderr, status = SyncedFolderMutagen.call_mutagen("pause", vm.name)
                    if status != 0
                        vm.ui.error stderr.strip
                    end
                end
            end
        end
        class Resume < Vagrant.plugin("2", :command)
            def self.synopsis
                "resumes all sync sessions to the machine"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    stdout, stderr, status = SyncedFolderMutagen.call_mutagen("resume", vm.name)
                    if status != 0
                        vm.ui.error stderr.strip
                    end
                end
            end
        end
        class List < Vagrant.plugin("2", :command)
            def self.synopsis
                "lists the sync sessions"
            end
            def execute()
                options = {}
                parser = OptionParser.new do |option|
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    SyncedFolderMutagen.parse_sessions(vm).each do |session|
                        def ui_opts(side)
                            {}.tap do |uiopts|
                                uiopts[:new_line] = false
                                uiopts[:prefix] = false
                                uiopts[:color] = side["Connection state"] == "Connected" ? :green : :yellow
                            end
                        end

                        vm.ui.detail "", **{ new_line: false }
                        vm.ui.detail "#{session["Alpha"]["URL"]}", **ui_opts(session["Alpha"])
                        vm.ui.detail " => ", **{ new_line: false, prefix: false }
                        vm.ui.detail "#{session["Beta"]["URL"]}", **ui_opts(session["Beta"])
                        vm.ui.detail " (#{session["Status"]})", **{ prefix: false }
                    end
                end
            end
        end

        class Wait < Vagrant.plugin("2", :command)
            def self.synopsis
                "waits for all sync sessions to be idle"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.on("--timeout TIMEOUT", "Wait for TIMEOUT seconds") do |o|
                        options[:timeout] = o.to_i
                    end
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    waitcount = 0
                    begin
                        Timeout::timeout(options[:timeout]) do
                        loop do
                            waiting = nil
                            SyncedFolderMutagen.parse_sessions(vm).each do |session|
                                unless ["Watching for changes"].include?(session["Status"])
                                    waiting = session
                                    break
                                end
                            end
                            if waiting
                                options = { new_line: false }
                                waitcount += 1
                                vm.ui.clear_line
                                alpha = waiting["Alpha"]
                                options[:color] = alpha["Connection state"] != "Connected" ? :yellow : :green
                                vm.ui.detail "[#{waitcount}] Waiting for #{alpha["URL"]} => #{waiting["Beta"]["URL"]}: #{waiting["Status"]}", **options
                                sleep(3)
                            else
                                break
                            end
                        end
                    end
                    rescue Timeout::Error
                        vm.ui.detail "", **{ prefix: false } # flush newline
                        vm.ui.error "Timed out waiting"
                        return 1
                    end
                end
            end
        end
    end
end
