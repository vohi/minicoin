module Minicoin
    module Metal
        autoload :Builder,       'vagrant/action/builder'

        class ActionUp
            def initialize(machine)
                @machine = machine
                @logger = Log4r::Logger.new("minicoin::metal::up")
            end
            def call(env)
                @machine.ui.info "Metal::ActionUp called"
                stateFile = File.join(@machine.data_dir, "state")
                if File.exist?(stateFile)
                    @machine.ui.warn "Machine already running"
                else
                    File.open(stateFile, "w") do |out|
                        out.puts "machine registered"
                    end
                end
            end
        end
        class ActionHalt
            def initialize(machine)
                @machine = machine
                @logger = Log4r::Logger.new("minicoin::metal::halt")
            end
            def call(env)
                @machine.ui.info "Metal::ActionHalt called"
            end
        end
        class ActionDestroy
            def initialize(machine)
                @machine = machine
                @logger = Log4r::Logger.new("minicoin::metal::destroy")
            end
            def call(env)
                @machine.ui.info "Metal::ActionDestroy called"
                if (File.delete(File.join(@machine.data_dir, "state") == 0))
                    @machine.ui.error "Machine was not created"
                end
            end
        end

        class Provider < Vagrant.plugin(2, :provider)
            def self.usable?(raise_error = false)
                # we are always usable
                true
            end
            def initialize(machine)
                @machine = machine
                @minicoin = machine.config.minicoin.machine
                @state_file = File.join(@machine.data_dir, "state")
            end
            def action(name)
                Vagrant::Action::Builder.new.tap do |b|
                    case name
                    when :up
                        b.use ActionUp.new(@machine)
                        b.use Vagrant::Action::Builtin::SyncedFolders
                    when :halt
                        b.use ActionHalt.new(@machine)
                    when :destroy
                        b.use ActionDestroy.new(@machine)
                    when :ssh
                        b.use Vagrant::Action::Builtin::SSHExec
                    when :provision
                        b.use Vagrant::Action::Builtin::Provision
                    else
                        raise "Metal asked for unsupported action #{name}"
                    end
                end
            end
            def machine_id_changed
                puts "Metal informed about machine_id_changed"
            end
            def ssh_info
                ssh_config = {}
                begin
                    ssh_config_file = "#{$HOME}/.ssh/config"
                    host = nil
                    File.open(ssh_config_file, "r").each do |line|
                        line.rstrip!
                        if line.empty?
                            host = nil
                        elsif host
                            pair = line.lstrip!.split
                            key = pair.first
                            value = pair.last
                            ssh_config[key] = value
                        elsif line == "Host #{@machine.name}"
                            host = @machine.name
                        end
                    end
                rescue
                    # no ssh config file
                end
                private_key = @minicoin["keypath"] || "#{$HOME}/.ssh/id_rsa"
                username = @minicoin["user"] || ssh_config["User"] || "vagrant"
                hostname = @minicoin["hostname"] || ssh_config["HostName"]
                if !hostname || hostname.empty? || username.empty?
                    @machine.ui.error "The SSH host for machine #{@machine.name} is not configured"
                    raise "Invalid or incomplete SSH configuration for #{@machine.name}"
                end
                if !File.exist?(private_key)
                    @machine.ui.error "No keypath defined for #{@machine.name} and default key not found"
                    raise "Invalid or incomplete SSH configuration for #{@machine.name}"
                end
                {
                    host: hostname,
                    port: "#{@minicoin["port"] || ssh_config["Port"] || 22}",
                    username: username,
                    remote_user: username,
                    private_key_path: private_key
                }
            end
            def state
                if !@statecache
                    if !File.exist?(@state_file)
                        return Vagrant::MachineState.new(:not_created, "not created", "Initialize the machine with `minicoin up`.")
                    end
                    if @machine.communicate.ready?
                        @statecache = Vagrant::MachineState.new(:running, "running", "The metal machine is running and could be reached.\n" +
                                                                                     "You can run jobs on it with `minicoin run`.")
                    end
                        return Vagrant::MachineState.new(:not_running, "not running", "Machine can not be reached via the communicator.\n" +
                                                                        "Make sure it runs SSH, and that the machine is configured\n" +
                                                                        "correctly.")
                end
                @statecache
            end

            private
                @state_file
                @machine
                @minicoin
                @statecache = nil
        end
    end
end
