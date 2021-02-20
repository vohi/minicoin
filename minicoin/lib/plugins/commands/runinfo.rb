module Minicoin
    class RunInfo < Vagrant.plugin("2", :command)
        def self.synopsis
            "show how jobs will be run"
        end

        def initialize(argv, env)
            super
        end
        def execute()
            parser = OptionParser.new do |option|
                option.banner = "Usage: minicoin runinfo [name|id]"
                option.separator ""
            end
            argv = parse_options(parser)
            return if !argv

            with_target_vms(argv) do |vm|
                keys = vm.config.instance_variable_get('@keys')
                minicoin = keys[:minicoin]
                machine = minicoin.machine

                name = machine["name"]
                project_dir = ENV["MINICOIN_PROJECT_DIR"]
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
                if @env.ui.is_a?(Vagrant::UI::MachineReadable)
                    @env.ui.output name, machine['os'], vm.config.vm.communicator, minicoin.guest_homes, $USER, ENV["HOME_SHARE"], guest_dir, { :target => self.class }
                else
                    @env.ui.output "Name        : #{name}"
                    @env.ui.output "OS          : #{machine['os']}"
                    @env.ui.output "Communicator: #{vm.config.vm.communicator}"
                    @env.ui.output "Guest homes : #{minicoin.guest_homes}"
                    @env.ui.output "Host user   : #{$USER}"
                    @env.ui.output "Home share  : #{ENV['HOME_SHARE']}"
                    @env.ui.output "Guest PWD   : #{guest_dir}"
                end
            end
        end
    end
end
