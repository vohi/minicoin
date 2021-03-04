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
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?
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
                    dirname = File.dirname(beta)
                    dirname = "../#{dirname}" if vm.guest.name == :windows

                    vm.communicate.execute("mkdir -p #{dirname}") do |type, data|
                        vm.ui.error data.strip if type == :stderr
                    end

                    opt_str += " --label minicoin=#{vm.name}"
                    beta_str = "#{vm.ssh_info[:username]}@#{vm.ssh_info[:host]}:#{vm.ssh_info[:port]}:#{beta}"

                    stdout, stderr, status = Open3.capture3("#{SyncedFolderMutagen.mutagen_path} sync create #{opt_str} #{alpha} #{beta_str}")
                    if status != 0
                        vm.ui.error stderr.strip
                    else
                        vm.ui.detail stdout.strip
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
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?

                if !options[:all] && !options[:alpha]
                    raise Vagrant::Errors::StandardError
                end

                with_target_vms(argv) do |vm|
                    if options[:all]
                        stdout, stderr, status = SyncedFolderMutagen.call_mutagen("terminate", vm.name)
                        vm.ui.error stderr.strip if status != 0
                        vm.ui.detail stdout unless stdout.empty?
                    else
                        sessions = SyncedFolderMutagen.parse_sessions(vm)
                        sessions.each do |session|
                            if /#{options[:alpha]}/.match?(session["Alpha"]["URL"])
                                stdout, stderr, status = SyncedFolderMutagen.call_mutagen("terminate", nil, session["Identifier"])
                                vm.ui.error stderr.strip if status != 0
                                vm.ui.detail stdout unless stdout.empty?
                            end
                        end
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
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?

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
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?

                with_target_vms(argv) do |vm|
                    stdout, stderr, status = SyncedFolderMutagen.call_mutagen("resume", vm.name)
                    if status != 0
                        vm.ui.error stderr.strip
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
                end

                argv = parse_options(parser)
                return if !argv
                raise Vagrant::Errors::MultiVMTargetRequired if argv.empty?

                with_target_vms(argv) do |vm|
                    sessions = SyncedFolderMutagen.parse_sessions(vm)
                    waiting = ""
                    waitcount = 0
                    while waiting
                        waiting = nil
                        sessions.each do |session|
                            unless ["Watching for changes"].include?(session["Status"])
                                waiting = session
                                break
                            end
                        end
                        if waiting
                            puts waiting
                            options = { new_line: false }
                            waitcount += 1
                            vm.ui.clear_line
                            alpha = waiting["Alpha"]
                            options[:color] = alpha["Connection state"] != "Connected" ? :yellow : :green
                            vm.ui.detail "[#{waitcount}] Waiting for #{alpha["URL"]} => #{waiting["Beta"]["URL"]}: #{waiting["Status"]}", options
                            sleep(3)
                        end
                    end
                end
            end
        end
    end
end
