class VagrantMock
  def initialize()
  end

  def require_version(expr)
  end

  def configure(version)
  end
end

class Vm
  def initialize(type)
    @guest = type
  end
  def guest()
    return @guest
  end
end

class Box
  def initialize(type)
    @vm = Vm.new(type)
  end
  def vm()
    return @vm
  end
end

Vagrant = VagrantMock.new

load 'Vagrantfile'

class Tester
    @error_count
    def initialize()
        @error_count = 0
        load_minicoin()
    end
    def test_expand_env()
        test_data = {
            "plain" => [:windows, "foo", "foo"],
            "$home_win" => [:windows, "$HOME", "C:\\Users\\host"],
            "$home_nix" => [:linux, "$HOME", "/home/host"],
            "$home_mac" => [:darwin, "$HOME", "/Users/host"]
        }
        test_data.each do |name, data|
            guest = data[0]
            input = data[1]
            output = data[2]

            box = Box.new(guest)
            result = expand_env(input, box)
            if result != output
                puts "Fail! for '#{name}', produced '#{result}', expected '#{output}'"
                @error_count += 1
            end
        end

        box = Box.new(:linux)
        test_data = {
            "$HOME" => "C:\\Users\\host"
        }

    end
    def error()
        return @error_count
    end

    def run()
        test_expand_env()
    end
end

tester = Tester.new
tester.run()
if tester.error != 0
    puts "Test failed: #{tester.error} encountered!"
else
    puts "Success!"
end