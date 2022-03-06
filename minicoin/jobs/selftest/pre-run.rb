module Selftest
    def self.pre_run(vm, *args)
        vm.ui.info "Pre-run for #{vm.name}"
    end
end
