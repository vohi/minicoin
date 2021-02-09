require 'json'

json = JSON.parse(File.read(ARGV[0]))

json["versions"][-1]["providers"].each do |provider|
    uri = URI::parse provider["url"]
    puts uri.path
end
