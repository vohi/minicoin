require 'find'

module Minicoin
    module Errors
        class MinicoinError < Vagrant::Errors::VagrantError
            def initialize(detail=nil)
                @detail = detail
                super
            end
            error_namespace("minicoin.errors")
        end
        class MissingArgument < MinicoinError
            def error_message; "Missing argument: #{@detail}; see --help for instructions!"; end
        end
        class CloudNotReady < MinicoinError
            def error_message; "Cloud provider not ready: #{@detail}"; end
        end
        class NOSSHServerOnHost < MinicoinError
            error_message("No SSH server detected on host, can't mount host folder!")
        end
        class NOSSHFSOnGuest < MinicoinError
            error_message("SSHFS is not installed on the guest, can't mount host folder!")
        end
        class SSHConnectionTimeout < MinicoinError
            error_message("Connection to SSH server on host timed out")
        end
        class MutagenNotFound < MinicoinError
            error_message("Mutagen is not installed on the host")
        end
        class NoSshKey < MinicoinError
            error_message("User has no default SSH key in ~/.ssh")
        end
        class MutagenSyncFail < MinicoinError
            error_message("Mutagen failed to create the sync session")
        end
        class DownloadError < MinicoinError
            def error_message; "Could not download file: #{@detail}"; end
        end
        class PreRunFail < MinicoinError
            def error_message; "Pre-run script returned with error:\n#{@detail}"; end
        end
        class PostRunFail < MinicoinError
            def error_message; "Post-run script returned with error:\n#{@detail}"; end
        end
    end

    # startup argument parsing
    argv = ARGV.dup
    mstart = ["run", "mutagen"].include?(argv[0]) ? 2 : 1 # skip subcommands
    @@requested_boxes = []
    for a in mstart ... argv.length
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
    if Vagrant.version?(">= 2.2.14")
        OptionParser = Vagrant::OptionParser
    end

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
    def self.get_config(machine)
        keys = machine.config.instance_variable_get('@keys')
        return keys[:minicoin]
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

    Find.find(".") do |path|
        if path =~ /.*\/plugin.rb$/
            Vagrant.global_logger.debug "Loading plugin #{path}"
            require path
        end
    end

end
