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