module Minicoin
    module MinicoinConfiguration
        class Minicoin < Vagrant.plugin(2, :config)
            attr_accessor :machine
            attr_accessor :fs_mappings
            attr_accessor :actual_shared_folders
            attr_accessor :guest_homes

            def initialize
                super
                @machine = UNSET_VALUE
                @fs_mappings = {}
                @actual_shared_folders = {}
                @hash = UNSET_VALUE
                @guest_homes = UNSET_VALUE
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
                    result.actual_shared_folders = actual_shared_folders.merge(other.actual_shared_folders)
                    result.guest_homes = other.guest_homes if @guest_homes == UNSET_VALUE
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
                    hash[var_name] = instance_variable_get(var) unless var_name.start_with?("_")
                end
                hash
            end
        end
    end
end
