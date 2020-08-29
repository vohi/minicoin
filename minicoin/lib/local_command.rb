module LocalCommand
    class Config < Vagrant.plugin("2", :config)
        attr_accessor :code
    end

    class Plugin < Vagrant.plugin("2")
        name "local_command"

        config(:local_command, :provisioner) do
            Config
        end

        provisioner(:local_command) do
            Provisioner
        end
    end

    class Provisioner < Vagrant.plugin("2", :provisioner)
        def provision
            if config.code.is_a?(Proc)
                config.code.call(@machine)
            else
                raise "'code' need to be a proc or lambda"
            end
        end
    end
end
