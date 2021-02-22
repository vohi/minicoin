module Minicoin
    module Commands
        class LS < Vagrant.plugin("2", :command)
            def self.synopsis
                "lists the file system contents on the guest"
            end

            def initialize(argv, env)
                super
            end

            def execute()
                options = {}
                options[:path] = nil
                options[:ls_args] = "-la"
                options[:dir_args] = ""

                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin ls [options] [name|id] [-- extra ls args]"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                    option.on("--path PATH", "-p PATH", "Specifies the path to list") do |path|
                        options[:path] = path
                    end
                    option.on("-- extra ls args", "Arguments passed through to the list command")
                end

                # everything after the "--" goes to ls/dir
                split_index = @argv.index("--")
                if split_index
                    options[:ls_args] = options[:dir_args] = @argv.drop(split_index + 1).join(" ")
                    @argv = @argv.take(split_index)
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(argv) do |vm|
                    unless vm.communicate.ready?
                        vm.ui.error "Machine not ready"
                        next
                    end
                    path = options[:path].dup
                    vm.ui.info "Contents of #{path || "home"}:"
                    path ||= ""
                    if vm.guest.name == :windows
                        path.gsub!("/", "\\")
                        vm.communicate.execute("cd \$Env:USERPROFILE; cmd /c dir #{options[:dir_args]} #{path}") do |type, data|
                            echo(vm.ui, type, data.rstrip)
                        end
                    else
                        path.gsub!("\\", "/")
                        vm.communicate.execute("ls #{options[:ls_args]} #{path}") do |type, data|
                            echo(vm.ui, type, data.chomp)
                        end
                    end
                end
            end

            private

            def echo(ui, type, data)
                if type == :stderr
                    ui.error data
                else
                    @env.ui.output data
                end
            end
        end
    end
end
