require "vagrant"
require "open3"

module Minicoin
    module SyncedFolderMutagen
        class MutagenAction
            def initialize(app, callbacks)
                @app = app
                @callbacks = callbacks
            end
        end
        class MutagenDestroy < MutagenAction
            @@terminated = {} # we get called multiple times, only terminate once

            def call(env)
                machine = env[:machine]
                return if machine.state.id == :not_created
                unless @@terminated[machine.id]
                    @@terminated[machine.id] = true
                    ssh_info = machine.ssh_info || {}
                    # machine.ui.warn "Terminating mutagen sessions for #{machine.name} #{machine.state.id}"
                    SyncedFolderMutagen.call_mutagen("terminate", machine.name)
                    SyncedFolderMutagen.remove_known_host(ssh_info) unless ssh_info[:host].nil?
                end
                @app.call(env)
            end
        end

        class MutagenSuspend < MutagenAction
            def call(env)
                machine = env[:machine]
                return if !machine.ssh_info
                #machine.ui.warn "Pausing mutagen sessions for #{machine.name}"
                SyncedFolderMutagen.call_mutagen("pause", machine.name)
                @app.call(env)
            end
        end
        class MutagenResume < MutagenAction
            def call(env)
                @app.call(env)
                machine = env[:machine]
                return if !machine.ssh_info
                #machine.ui.warn "Resuming mutagen sessions for #{machine.name}"
                SyncedFolderMutagen.call_mutagen("resume", machine.name)
            end
        end
    end
end
