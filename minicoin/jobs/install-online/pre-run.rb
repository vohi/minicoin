module Install_online
    def self.pre_run(vm)
        paths = [
            "#{ENV['HOME']}/Library/Application Support/Qt",
            "#{ENV['HOME']}/.local/share/Qt",
            "#{ENV['USERPROFILE']}/AppData/Roaming/Qt"
        ]
        paths.each do |path|
            if File.directory?(path)
                account_file = "qtaccount.ini"
                account_path = File.join(path, account_file)
                if File.exist?(account_path)
                    return vm.communicate.upload(account_path, account_file)
                else
                    raise Minicoin::Errors::PreRunFail.new("No qtaccount.ini file found in #{path}, please set your account up locally.")
                end
            end
        end
        raise Minicoin::Errors::PreRunFail.new("Not able to locate qtaccount.ini file on #{RUBY_PLATFORM}")
    end
end
