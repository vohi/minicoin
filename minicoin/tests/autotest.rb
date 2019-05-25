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

load '../Vagrantfile'

class Tester
  @error_count
  @data_count
  def initialize()
    @error_count = 0
    @data_count = 0
    load_env()
  end

  def load_env()
    root = File.join($PWD, "tests")
    test_file = File.join(root, "test.yml")
    user_file = File.join(root, "user.yml")

    test_output = YAML.load_file(test_file)
    user_output = YAML.load_file(user_file)
    if !test_output
      test_output = nil
    end
    if !user_output
      user_output = nil
    end

    test_output = load_includes(test_output, root)
    user_output = load_includes(user_output, root)
    load_boxes(test_output, user_output)
    load_settings(test_output, user_output)
    load_urls(test_output, user_output)

    test_data = {
      "settings" => {
        "value" => ["sub", "subsub", "test"],
        "newvalue" => "local_option",
        "home_share" => ENV['HOME']
        },
      "urls" => {
        "domain" => ["domain1", "domain2", "subdomain1", "subdomain2", "leaf1", "leaf2", "userserver"],
        "userdomain" => ["a", "b"]
        },
      "includes" => ["include/sub.yml"],
      "machines" => [
        {"name" => "machine1", "box" => "generic", "gui" => false },
        {"name" => "machine2"},
        {"name" => "override", "gui" => true},
        {"name" => "submachine", "box" => "subgeneric"},
        {"name" => "machine1", "box" => "duplicate", "gui" => true }
      ]
    }

    test_data.each do |name, data|
      @data_count += 1
      result = test_output[name]
      if result != data
        puts "Fail for '#{name}', produced '#{result}', expected '#{data}'"
        @error_count += 1
      end
    end
  end
  def test_expand_env()
    user = ENV["USER"]
    test_data = {
      "plain" => [:windows, "foo", "foo"],
      "$home_win" => [:windows, "$HOME", "C:\\Users\\host"],
      "$home_nix" => [:linux, "$HOME", "/home/host"],
      "$home_mac" => [:darwin, "$HOME", "/Users/host"],
      "$user" => [nil, "$USER", user],
      "$user$user" => [nil, "$USER$USER", "#{user}#{user}"]
    }

    test_data.each do |name, data|
      @data_count += 1
      guest = data[0]
      input = data[1]
      output = data[2]

      box = Box.new(guest) unless guest.nil?
      result = expand_env(input, box)
      if result != output
        puts "Fail! for '#{name}', produced '#{result}', expected '#{output}'"
        @error_count += 1
      end
    end
  end

  def errors()
    return @error_count
  end

  def tested()
    return @data_count
  end

  def run()
    test_expand_env()
  end
end

tester = Tester.new
tester.run()
if tester.errors != 0
  puts "Test failed: #{tester.error} encountered!"
else
  puts "Success after #{tester.tested} tests!"
end