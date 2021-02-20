module Minicoin
    # startup argument parsing
    argv = ARGV.dup
    @@requested_boxes = []
    for a in 1 ... argv.length
        arg = argv[a]
        next if arg.start_with?("-")
        @@requested_boxes << argv[a]
    end

    # this is a simplified version of Vagrant's ui selection code from bin/vagrant.rb
    ui_class = Vagrant::UI::Colored

    if argv.include?("--no-color") || ENV["VAGRANT_NO_COLOR"]
        ui_class = Vagrant::UI::Basic
    elsif !Vagrant::Util::Platform.terminal_supports_colors?
        ui_class = Vagrant::UI::Basic
    elsif !$stdout.tty? && !Vagrant::Util::Platform.cygwin?
        ui_class = Vagrant::UI::Basic
    end
    if argv.include?("--color") || ENV["VAGRANT_FORCE_COLOR"]
        ui_class = Vagrant::UI::Colored
    end
    if argv.include?("--machine-readable")
        ui_class = Vagrant::UI::MachineReadable
    end
    # Setting to enable/disable showing progress bars
    if argv.include?("--no-tty")
        ui_class = Vagrant::UI::NonInteractive
    end

    # use the default Vagrant option parser class in Minicoin commands
    OptionParser = Vagrant::OptionParser

    @@machines = []
    @@ui = ui_class.new
    def self.machines=(data)
        @@machines = data
    end
    def self.machines
        @@machines
    end
    def self.ui
        @@ui
    end
    def self.requested_boxes
        @@requested_boxes
    end

    # find out if the machine's name matches the parameters
    def self.skip?(machine)
        name = machine["name"]
        if name.nil?
             @@ui.warn "Machine without name: #{machine}"
            return true
        end
        return false if requested_boxes.empty?
        requested = false
        for requested_box in requested_boxes
            if requested_box.start_with?("/") && requested_box.end_with?("/")
                requested = name =~ /#{requested_box[1..requested_box.length - 2]}/
            elsif requested_box == name
                requested = true
            end
            break if requested
        end
        if !requested
            Vagrant.global_logger.warn "Skipping #{name}"
            return true
        end
        false
    end
    
    class Plugin < Vagrant.plugin("2")
        name "Minicoin extensions"

        config(:minicoin) do
            require_relative "plugins/configs/minicoin.rb"
            Minicoin
        end

        config(:local_command, :provisioner) do
            require_relative "plugins/provisioners/local_command.rb"
            LocalCommand::Config
        end

        provisioner(:local_command) do
            require_relative "plugins/provisioners/local_command.rb"
            LocalCommand::Provisioner
        end

        command(:list) do
            require_relative "plugins/commands/list.rb"
            List
        end

        command(:describe, primary: false) do
            require_relative "plugins/commands/describe.rb"
            Describe
        end

        command(:runinfo, primary: false) do
            require_relative "plugins/commands/runinfo.rb"
            RunInfo
        end

        command(:jobconfig, primary: false) do
            require_relative "plugins/commands/jobconfig.rb"
            JobConfig
        end
    end
end
