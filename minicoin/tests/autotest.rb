# Mocking classes for testing Vagrant
# THe hierarchy is MockVagrant -> MockConfig -> MockVM -> MockBox
class MockVagrant
  def initialize()
    @config = MockConfig.new()
    @plugin = MockPlugin.new()
  end
  def require_version(expr)
  end
  def configure(version)
    yield @config
  end
  def config()
    return @config
  end
  def plugin(a, b="default")
    MockPlugin
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

class MockPlugin
  def initialize()
  end
  def self.name(n)
  end
  def self.config(a, b)
  end
  def self.provisioner(a)
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

class Tester
  @error_count

  def initialize()
    @error_count = 0
    @data_count = 0
  end

  def test_merge_yaml()
    test_base = [
      {"key" => "value"},
      {"array" => ["array"]},
      {"hash" => { "key" => "value", "key2" => "value2"}}
    ]
    test_user = [
      {},
      {"key" => "value2"},
      {"array" => ["array2"]},
      {"hash" => { "key" => "value0", "key2" =>nil, "key3" => "value3"}},
      {"key" => nil},
      {"array" => [nil, "array2"]},
    ]
    test_result = [
      # 0
      {"key"=>"value"},
      {"key" => "value2"},
      {"key" => "value", "array"=>["array2"]},
      {"key"=>"value", "hash"=>{"key"=>"value0", "key2" => nil, "key3"=>"value3"}},
      {},
      {"key"=>"value", "array"=>[nil, "array2"]},
      # 6
      {"array"=>["array"]},
      {"array"=>["array"], "key"=>"value2"},
      {"array"=>["array", "array2"]},
      {"array"=>["array"], "hash"=>{"key"=>"value0", "key2" => nil, "key3"=>"value3"}},
      {"array"=>["array"], "key"=>nil},
      {"array"=>["array2"]},

      # 12
      {"hash"=>{"key"=>"value", "key2"=>"value2"}},
      {"hash"=>{"key"=>"value", "key2"=>"value2"}, "key"=>"value2"},
      {"hash"=>{"key"=>"value", "key2"=>"value2"}, "array"=>["array2"]},
      {"hash"=>{"key"=>"value0", "key3"=>"value3"}},
      {"hash"=>{"key"=>"value", "key2"=>"value2"}, "key"=>nil},
      {"hash"=>{"key"=>"value", "key2"=>"value2"}, "array"=>[nil, "array2"]}
    ]

    @data_count = 0
    result_index = 0
    test_base.each do |base|
      test_user.each do |user|
        @data_count += 1
        base_copy = base.clone
        result = merge_yaml(base_copy, user)
        if result != test_result[result_index]
          puts "Failure for index #{result_index}:"
          puts "=> input: #{base_copy} + #{user}"
          puts "=> produced: #{result}"
          puts "=> expected: #{test_result[result_index]}"
        end
        result_index += 1
      end
    end
  end

  def test_loading()
    test_output = load_testmachines()
    test_data = {
      "settings" => {
        "single" => "subsub",
        "array" => ["test", "sub", "subsub"],
        "global" => "user",
        "list" => ["user1", "user2"],
        "home_share" => "$HOME",
        "newvalue" => "local_option",
        "defaults" => {}
        },
      "urls" => {
        "domain" => ["domain1", "domain2", "subdomain1", "subdomain2", "leaf1", "leaf2", "userserver"],
        "userdomain" => ["a", "b"]
        },
      "includes" => ["include/sub.yml"],
      "machines" => [
        {"name" => "machine1", "box" => "generic", "gui" => false },
        {"name" => "machine2", "box" => "generic2"},
        {"name" => "override", "gui" => true},
        {"name" => "environment1", "box" => "$USER"},
        {"name" => "environment2", "box" => "private/$minicoin_key/box"},
        {"name" => "base", "box" => "generic",
                           "roles" => [{"role" => "hello-world"}, {"role" => "script", "script" => "hello"}],
                           "private_net" => "1.1.1.1"
        },
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
      @data_count += 1
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
      "$home_win" => [:windows, "$HOME", ENV["HOME"].gsub("/", "\\")],
      "$home_nix" => [:linux, "$HOME", ENV["HOME"]],
      "$home_mac" => [:darwin, "$HOME", ENV["HOME"]],
      "$user" => [nil, "$USER", user],
      "$user$user" => [nil, "$USER$USER", "#{user}#{user}"],
      "$$PWD" => [nil, "$$PWD", "$PWD"],
      "echo guest home" => [nil, "echo $$HOME", "echo $HOME"],
      "both" => [nil, "echo $USER $$USER $USER $$USER", "echo #{user} $USER #{user} $USER"]
    }

    test_data.each do |name, data|
      @data_count += 1
      guest = data[0]
      input = data[1]
      output = data[2]

      box = MockVm.new(guest)
      old_env = ENV["GUEST_HOMES"]
      ENV["GUEST_HOMES"] = "#{guest}"
      result = expand_env(input, box)
      if result != output
        puts "Fail! for '#{name}'!"
        puts "=> produced: '#{result}'"
        puts "=> expected: '#{output}'"
        @error_count += 1
      end
      ENV["GUEST_HOMES"] = old_env
    end
  end

  def errors()
    return @error_count
  end

  def tested()
    return @data_count
  end

  def run()
    test_merge_yaml()
    test_loading()
    test_vagrantfile()
    test_expand_env()
  end
end

begin
  load '../Vagrantfile'

  tester = Tester.new
  tester.run()
  if tester.errors != 0
    puts "Test failed: #{tester.errors} encountered!"
  else
    puts "Success after #{tester.tested} tests!"
  end
rescue => error
  puts "Test failed while loading:"
  puts error
end
