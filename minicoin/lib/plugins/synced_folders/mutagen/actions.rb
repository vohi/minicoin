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
