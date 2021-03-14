# Mocking classes for testing Vagrant
# THe hierarchy is MockVagrant -> MockConfig -> MockVM -> MockBox
module Vagrant
  @@config = nil
  def self.config
    @@config = MockConfig.new unless @@config
    @@config
  end
  def self.version?(x)
    true
  end
  def self.has_plugin?(x)
    true
  end

  class OptionParser
  end

  module UI
    class Basic
    end
    class Colored
    end
    class Prefixed
      def initialize(a, b)
      end
      def warn(*)
      end
    end
  end
  module Util
    class Platform
      def self.terminal_supports_colors?()
        false
      end
      def self.windows?
        false
      end
    end
  end
  def self.require_version(expr)
  end
  def self.plugin(a, b="default")
    MockPlugin
  end
  def self.configure(version)
    yield config
  end
  
  class MockVagrant
    def initialize()
      @plugin = MockPlugin.new()
      @sensitive = Array.new
    end
    def sensitive
      @sensitive
    end
    def sensitive=(sensitive)
      @sensitive << sensitive
    end
    def config
      Vagrant.config
    end
  end

  module Plugin
    module V2
      module Plugin
        class MockManager
          def registered
            []
          end
        end
        def self.manager
          MockManager.new
        end
      end
    end
  end
  module Errors
    class VagrantError
      def self.error_namespace(x)
      end
      def self.error_message(m)
      end
    end
  end
end

class MockConfig
  def initialize()
    @vm = MockVm.new(nil)
    @vagrant = Vagrant::MockVagrant.new
  end
  def vm()
    return @vm
  end
  def vagrant
    @vagrant
  end
  def vagrant=(vagrant)
    @vagrant = vagrant
  end
end

class MockPlugin
  def initialize()
  end
  def self.command(x, b=false)
  end
  def self.name(n)
  end
  def self.config(a, b=0)
  end
  def self.provisioner(a)
  end
  def self.synced_folder(*)
  end
end

class MockWinssh
  def insert_key=(a)
  end
end

class MockVm
  attr_accessor :minicoin

  def initialize(type)
    @guest = type
    @box = ""
    @url = ""
    @box_url = ""
    @communicator = :ssh
    @boxes = {}
    @minicoin = MockMinicoin.new
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
  def box_url()
    @box_url
  end
  def box_url=(box_url)
    @box_url = box_url
  end
  def communicator()
    @communicator
  end
  def communicator=(communicator)
    @communicator = communicator
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
  def winssh()
    MockWinssh.new
  end
end

class MockTrigger
  def before(a)
  end
  def after(a)
  end
end

class MockMinicoin
  attr_accessor :machine
  attr_accessor :fs_mappings
  attr_accessor :actual_shared_folders
  attr_accessor :hash
  attr_accessor :guest_homes

  def initialize
    @fs_mappings = {}
    @actual_shared_folders = {}
    @hash = -1
    @guest_homes = nil
  end
end
