module Minicoin
    module MinicoinConfiguration
        class Minicoin < Vagrant.plugin(2, :config)
            attr_accessor :machine
            attr_accessor :fs_mappings
            attr_accessor :default_shared_folders
            attr_accessor :guest_homes
            attr_accessor :guest_user

            def initialize
                super
                @machine = UNSET_VALUE
                @fs_mappings = {}
                @default_shared_folders = {}
                @hash = UNSET_VALUE
                @guest_homes = UNSET_VALUE
                @guest_user = "vagrant"
            end

            def hash()
                # Calculate a simple hash so that we can give each machine a well-defined
                # port number.
                # If we don't do that, then the port of a suspended or halted machine might
                # be re-used by vagrant, and then resuming the suspended machine will fail,
                # or result in traffic going the wrong way (ie with mutagen synching).

                @hash = @machine["name"].sum % 797 if @hash == UNSET_VALUE
                @hash
            end

            def merge(other)
                super.tap do |result|
                    result.fs_mappings = fs_mappings.merge(other.fs_mappings)
                    result.default_shared_folders = default_shared_folders.merge(other.default_shared_folders)
                    result.guest_homes = other.guest_homes if @guest_homes == UNSET_VALUE
                    result.guest_user = other.guest_user if @guest_homes == "vagrant"
                    result.machine = {} if machine == UNSET_VALUE && other.machine == UNSET_VALUE
                end
            end

            def validate(machine)
                errors = _detected_errors
                if @guest_homes == UNSET_VALUE
                    errors << "Couldn't determine location of home directories on guest"
                end
                { "minicoin" => errors }
            end

            def to_hash()
                hash = {}
                instance_variables.each do |var|
                    var_name = var.to_s[1..-1]
                    next if var_name.start_with?("_")
                    value = instance_variable_get(var)
                    next if value == UNSET_VALUE
                    hash[var_name] = value
                end
                hash
            end
        end
    end
end
