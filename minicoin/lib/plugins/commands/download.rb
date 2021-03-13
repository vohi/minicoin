module Minicoin
    module Commands
        class Download < Vagrant.plugin("2", :command)
            def self.synopsis
                "downloads from machine via communicator"
            end
            
            def execute()
                parser = OptionParser.new do |option|
                    option.banner = "Usage: minicoin download <source> [name|id]"
                    option.separator ""
                    option.separator "Options:"
                    option.separator ""
                end
                argv = parse_options(parser)
                source, argv = argv
                raise Vagrant::Errors::CLIInvalidUsage, help: parser.help.chomp if !argv
                
                with_target_vms(argv, single_target: true) do |vm|
                    unless vm.communicate.ready?
                        vm.ui.error "Machine not ready"
                        next
                    end
                    guest_homes = Minicoin.get_config(vm).guest_homes
                    destination = $MINICOIN_PROJECT_DIR
                    download_source = Pathname.new(source).absolute? ? source : "#{guest_homes}/#{vm.ssh_info[:remote_user]}/#{source}"
                    download_destination = File.join($MINICOIN_PROJECT_DIR, source)

                    @env.ui.info "Downloading #{download_source} to #{$MINICOIN_PROJECT_DIR}"
                    vm.communicate.download(download_source, $MINICOIN_PROJECT_DIR)
                    @env.ui.info "Download has completed successfully!"
                    @env.ui.info "  Source: #{download_source}"
                    @env.ui.info "  Destination: #{download_destination}"
                rescue Net::SCP::Error => e
                    raise Minicoin::Errors::DownloadError.new("#{e}")
                rescue => e
                    raise Vagrant::Errors::VagrantError
                end
            end
        end
    end
end
