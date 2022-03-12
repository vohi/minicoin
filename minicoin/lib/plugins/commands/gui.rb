module Minicoin
    module Commands
        class GUI < Vagrant.plugin("2", :command)
            def self.synopsis
                "open the UI for the virtual machine"
            end

            def execute()
                options = {}
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin gui [name|id]"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                end

                argv = parse_options(parser)
                return if !argv

                with_target_vms(@argv) do |vm|
                    case vm.box.provider
                    when "virtualbox", :virtualbox
                        vm.ui.info "Starting #{vm.id} UI with VBoxManage"
                        `VBoxManage startvm #{vm.id} --type separate`
                    when "vmware_desktop", :vmware_desktop
                        vm.ui.info "Opening #{vm.id}"
                        `#{start_command()} '#{vm.id}'`
                    else
                        provider_opened = false
                        if vm.provider.methods.include?(:open_gui)
                            vm.ui.info "Opening VM UI through provider"
                            provider_opened = vm.provider.open_gui(vm, start_command())
                        end
                        unless provider_opened
                            vm.ui.warn "Falling back to RDP for #{vm.name} using #{vm.box.provider}"
                            vm.env.cli("rdp", vm.name.to_s)
                        end
                    end
                end
            end

            private

            def start_command
                cmd = {
                    "linux" => "xdg-open",
                    "darwin" => "open",
                    "windows" => "cmd /C start",
                    "mingw" => "cmd /C start"
                }
                cmd = cmd.select do |key, value|
                    Vagrant::Util::Platform.platform.include?(key)
                end
                cmd.first[1]
            end
        end
    end
end
