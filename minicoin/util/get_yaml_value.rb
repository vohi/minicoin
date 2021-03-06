require 'yaml'

yaml=YAML.load(STDIN.read)

exit(1) unless yaml

if ARGV.count < 1
    yaml.each do |key, value|
        puts key
    end
else
    value = yaml[ARGV[0]]
    unless ARGV[1] == "--raw"
        if value.is_a?(String)
            value.gsub!("\\", "\\\\")
            value.gsub!("\"", "\\\"")
        end
    end
    puts value
end
