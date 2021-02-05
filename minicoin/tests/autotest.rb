require_relative "../lib/mock.rb"

Vagrant = MockVagrant.new

def load_testmachines()
  $PWD = File.join($PWD, "tests")
  $HOME = File.join($PWD, "user")
  ENV['MINICOIN_PROJECT_DIR'] = File.join($PWD, "local")
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

  def compare(name, actual, expected)
    actual.delete("fs_mappings")
    actual.delete("actual_shared_folders")

    if actual != expected
      puts "Fail for '#{name}'!"
      puts "=> produced: '#{actual}'"
      puts "=> expected: '#{expected}'"
      @error_count += 1
    end
  end

  def test_loading()
    test_output = $TEST_OUTPUT
    test_data = {
      "settings" => {
        "single" => "subsub",
        "array" => ["test", "sub", "subsub"],
        "global" => "user",
        "list" => ["user1", "user2"],
        "home_share" => "$HOME",
        "defaults" => { "shared_folders" => [{ "Host" => "Guest" }]},
        "newvalue" => "local_option",
        },
      "urls" => {
        "domain" => ["domain1", "domain2", "subdomain1", "subdomain2", "leaf1", "leaf2", "userserver"],
        "userdomain" => ["a", "b"]
        },
      "includes" => ["include/sub.yml"],
      "machines" => [
        {"name" => "machine1", "box" => "generic", "gui" => false, "shared_folders"=>[{"Host"=>"Guest"}], "os" => "macos", "nictype1" => "82545EM", "nictype2" => "82545EM" },
        {"name" => "machine2", "box" => "generic2", "shared_folders"=>[{"Host"=>"Guest"}], "os" => "macos", "nictype1" => "82545EM", "nictype2" => "82545EM" },
        {"name" => "override", "gui" => true, "shared_folders"=>[{"Host"=>"Guest"}]},
        {"name" => "environment1", "box" => "$USER", "shared_folders"=>[{"Host"=>"Guest"}], "os"=>"linux", "nictype2"=>nil },
        {"name" => "environment2", "box" => "private/$minicoin_key/box", "shared_folders"=>[{"Host"=>"Guest"}], "os"=>"linux", "nictype2"=>nil },
        {"name" => "base", "box" => "generic",
                           "roles" => [{"role" => "hello-world"}, {"role" => "script", "script" => "hello"}],
                           "shared_folders"=>[{"Host"=>"Guest"}],
                           "private_net" => "1.1.1.1", "os"=>"linux", "nictype2"=>nil
        },
        {"name" => "merged_role", "box" => "generic",
                                   "roles" => [
                                    {
                                      "role" => "upload",
                                      "files" => {
                                        "source" => "target",
                                        "source2" => "target2"
                                      }
                                    },
                                    {
                                      "role" => "merge_test",
                                      "attribute" => "value"
                                    },
                                    {
                                      "role" => "mutagen",
                                      "paths" => ["path2", "path1"]
                                    }
                                  ],
                                   "shared_folders"=>[{"Host"=>"Guest"}],
                                   "os"=>"linux", "nictype2"=>nil
        },
        {"name" => "submachine", "box" => "subgeneric", "shared_folders"=>[{"Host"=>"Guest"}], "os"=>"macos", "nictype1"=>"82545EM", "nictype2"=>"82545EM" },
        {"name" => "machine1", "box" => "duplicate", "gui" => true, "shared_folders"=>[{"Host"=>"Guest"}], "os"=>"macos", "nictype1"=>"82545EM", "nictype2"=>"82545EM" }
      ]
    }

    test_data.each do |name, data|
      @data_count += 1
      result = test_output[name]
      if result.is_a?(Array)
        index = 0
        result.each do |result_entry|
          result_entry.delete("hash") if result_entry.is_a?(Hash)
          compare(name, result_entry, data[index])
          index += 1
        end
      elsif result.is_a?(Hash)
        result.each do |result_key, result_value|
          compare(name, result_value, data[result_key])
        end
      else
        compare(name, result_entry, data)
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
    puts "=== Testing merge_yaml"
    test_merge_yaml()
    puts "=== Testing vagrantfile"
    test_vagrantfile()
    puts "=== Testing expand_env"
    test_expand_env()
    puts "=== Testing loading"
    test_loading()
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
