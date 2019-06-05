# Mocking classes for testing Vagrant
# THe hierarchy is MockVagrant -> MockConfig -> MockVM -> MockBox
class MockVagrant
  def initialize()
    @config = MockConfig.new()
  end
  def require_version(expr)
  end
  def configure(version)
    yield @config
  end
  def config()
    return @config
  end
end

class MockConfig
  def initialize()
    @vm = MockVm.new(nil)
  end
  def vm()
    return @vm
  end
end

class MockVm
  def initialize(type)
    @guest = type
    @box = ""
    @url = ""

    @boxes = {}
  end
  def vm()
    return self
  end
  def define(a, b=nil)
    vm = MockVm.new(nil)
    @boxes[a] = vm
    yield vm
  end
  def box()
    return @box
  end
  def box=(box)
    @box = box
  end
  def hostname=(hostname)
  end
  def guest()
    return @guest
  end
  def guest=(guest)
    @guest = guest
  end
  def network(a, b)
  end
  def communicator()
  end
  def provider(a)
  end
  def synced_folder(a, b, c=nil)
  end
  def provision(a, b)
  end
  def trigger()
    return MockTrigger.new()
  end
  def boxes()
    return @boxes
  end
end

class MockTrigger
  def before(a)
  end
  def after(a)
  end
end

Vagrant = MockVagrant.new

def load_testmachines()
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

  return test_output
end

load '../Vagrantfile'

class Tester
  @error_count
  @data_count
  def initialize()
    @error_count = 0
    @data_count = 0
  end

  def test_loading()
    test_output = load_testmachines()
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
        {"name" => "environment1", "box" => "$USER"},
        {"name" => "environment2", "box" => "private/$minicoin_key/box"},
        {"name" => "submachine", "box" => "subgeneric"},
        {"name" => "machine1", "box" => "duplicate", "gui" => true }
      ]
    }

    test_data.each do |name, data|
      @data_count += 1
      result = test_output[name]
      if result != data
        puts "Fail for '#{name}'!"
        puts "=> produced: '#{result}'"
        puts "=> expected: '#{data}'"
        @error_count += 1
      end
    end
  end

  def test_vagrantfile()
    test_data = {
      "machine1" => {
        "box" => "duplicate"
      },
      "environment1" => {
        "box" => ENV["USER"]
      },
      "environment2" => {
        "box" => "private/box"
      },
      "submachine" => {
        "box" => "subgeneric"
      }
    }

    box_data = {}
    Vagrant.config.vm.boxes.each do |name, box|
      box_data[name] = {}
      box_data[name]["box"] = box.box
    end
    test_data.each do |name, expected|
      if expected != box_data[name]
        puts "Fail for '#{name}'!"
        puts "=> produced: #{box_data[name]}"
        puts "=> expected: #{expected}"
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

      box = MockVm.new(guest) unless guest.nil?
      result = expand_env(input, box)
      if result != output
        puts "Fail! for '#{name}'!"
        puts "=> produced: '#{result}'"
        puts "=> expected: '#{output}'"
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
    test_loading()
    test_vagrantfile()
    test_expand_env()
  end
end

tester = Tester.new
tester.run()
if tester.errors != 0
  puts "Test failed: #{tester.errors} encountered!"
else
  puts "Success after #{tester.tested} tests!"
end