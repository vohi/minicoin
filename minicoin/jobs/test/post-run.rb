module Test
    def self.post_run(vm, *args)
        vm.ui.info "Post-run for #{vm.name}"
    end
end
