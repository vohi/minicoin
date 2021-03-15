require 'net/scp'

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
                    download_source.gsub!("\\", "/") # consistently platform independent slashes
                    if vm.guest.name == :windows
                        display_source = download_source.gsub("/", "\\")
                        is_directory = vm.communicate.test("if (Test-Path -Path '#{download_source}' -PathType Container) { exit 0 } else { exit 1 }")
                    else
                        display_source = download_source
                        is_directory = vm.communicate.test("[ -d '#{download_source}' ] && exit 0 || exit 1")
                    end
                    if is_directory
                        # ssh communicator can't download directories, doesn't pass -r through to scp :(
                        vm.ui.warn "The SSH communicator can't download directories, this will probably fail" if "#{vm.communicate.class}".include?("SSH")
                        download_destination = $MINICOIN_PROJECT_DIR.dup
                    else
                        # file - download only the file
                        download_destination = File.join($MINICOIN_PROJECT_DIR, File.basename(source))
                    end

                    if Vagrant::Util::Platform.windows?
                        download_destination.gsub!("/", "\\")
                    else
                        download_destination.gsub!("\\", "/")
                    end

                    @env.ui.info "Downloading #{is_directory ? 'directory' : 'file'} #{display_source} to #{download_destination}"
                    vm.communicate.download(download_source, download_destination)
                    @env.ui.info "Download has completed successfully!"
                    @env.ui.info "  Source: #{display_source}"
                    @env.ui.info "  Destination: #{download_destination}"
                rescue Net::SCP::Error => e
                    raise Minicoin::Errors::DownloadError.new("#{e}")
                end
            end
        end
    end
end
