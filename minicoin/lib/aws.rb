require 'json'
require 'net/http'
require 'ipaddr'
require 'open3'

class Hash
    def slice(*keep_keys)
        h = {}
        keep_keys.each { |key| h[key] = fetch(key) if has_key?(key) }
        h
    end unless Hash.method_defined?(:slice)
    def except(*less_keys)
        slice(*keys - less_keys)
    end unless Hash.method_defined?(:except)
end

module VagrantPlugins
    module AWS
        class Provider < Vagrant.plugin("2", :provider)
            @@aws_cli = Which.which("aws")
            @@aws_account = nil
            @@default_region = nil

            def call(service, method, json={})
                params = ""
                json.each do |option, value|
                    params += " --#{option} "
                    if value.is_a?(Hash)
                        first = true
                        value.each do |name, values|
                            params += ";" unless first
                            params += "Name=#{name},Values=#{values}"
                            first = false
                        end
                    elsif value.is_a?(String) && value.include?(" ") && !value.start_with?("\"")
                        params += " \"#{value}\""
                    else
                        params += " #{value}"
                    end
                end
                Open3.capture3("#{@@aws_cli} #{service} #{method} #{params}")
            end

            def self.check_cli()
                @@aws_cli
            end
            def self.default_region()
                @@default_region
            end

            def prepare_account(machine)
                return nil unless @@aws_account.nil?
                @@default_region = `#{@@aws_cli} configure get region`.strip
                return unless ['up', 'validate'].include?(ARGV[0]) # don't check AWS for check and shutdown operations
                begin
                    @@aws_account = "" # don't try again
                    # check that there are credentials
                    stdout, stderr, status = call(:sts, "get-caller-identity")
                    raise "Failed to read AWS account information" if status != 0
                    aws_profile = JSON.parse(stdout)
                    @@aws_account = aws_profile['Account']
                    machine.ui.info "Verifying AWs account #{@@aws_account}"

                    # verify that there is a default VPC
                    stdout, stderr, status = call(:ec2, "describe-vpcs", {
                        :filter => { "is-default" => true, "state" => "available"}
                    })
                    raise "Failed to read VPC information: #{stderr}" if status != 0
                    default_vpc = JSON.parse(stdout)['Vpcs'][0]
                    raise "No available default VPC found" if default_vpc.nil?
                    machine.ui.detail "Using Virtual private cloud #{default_vpc['VpcId']}"

                    # check if there's a minicoin security group, and create it if not
                    stdout, stderr, status = call(:ec2, "describe-security-groups", {
                        :filters => {
                            "group-name" => "minicoin",
                            "vpc-id" => default_vpc['VpcId']
                        }
                    })
                    raise "Failed to read security group information: #{stderr}" if status != 0
                    minicoin_group = JSON.parse(stdout)['SecurityGroups'][0]
                    if minicoin_group.nil?
                        machine.ui.detail "minicoin security group not found, creating..."
                        stdout, stderr, status = call(:ec2, "create-security-group", {
                            "group-name" => "minicoin",
                            "description" => "Default group for minicoin machines",
                            "vpc-id" => default_vpc['VpcId']
                        })
                        raise "Failed to create minicoin security group: #{stderr}" if status != 0
                        minicoin_group = JSON.parse(stdout)
                    end
                    minicoin_group_id = minicoin_group['GroupId']
                    # get the public IP address of this network (NOT just this host) as seen by AWS,
                    # and make sure that the minicoin security group lets us in. This means that we
                    # can connect to any instance on AWS from any public IP address from which an instance
                    # has been created.
                    public_ip = Net::HTTP.get(URI("https://api.ipify.org"))
                    hostname = Socket.gethostname
                    machine.ui.detail "Machines will be created with security group #{minicoin_group_id}, updating ingress rules for #{public_ip}"
                    ingress_rules = [ # Open up for
                        { :port => 22, :protocol => :tcp, :description => "SSH" },
                        { :port => 3389, :protocol => :tcp, :description => "RDP" },
                        { :port => 5985, :protocol => :tcp, :description => "WinRM-HTTP" },
                        { :port => 5986, :protocol => :tcp, :description => "WinRM-HTTPS" },
                        #  (https://support.apple.com/en-gb/guide/remote-desktop/apd0c903fec/mac)
                        { :port => 5900, :protocol => :tcp, :description => "VNC - Control and observe"},
                        { :port => 5900, :protocol => :udp, :description => "VNC - Send/share screen"},
                        { :port => 3283, :protocol => :tcp, :description => "VNC - Reporting"},
                        { :port => 3283, :protocol => :udp, :description => "VNC - Additional data"}
                    ]
                    ingress_permissions = minicoin_group['IpPermissions'] || []
                    ingress_rules.each do |rule|
                        # for every rule we want that doesn't have a matching entry in the existing permission, add
                        port = rule[:port]
                        protocol = rule[:protocol]
                        description = rule[:description]
                        ingress_permission = ingress_permissions.select do |permission|
                            next unless permission["FromPort"].to_i == port
                            next unless permission["IpProtocol"] == protocol.to_s
                            in_network = false
                            permission["IpRanges"].each do |iprange|
                                net = IPAddr.new(iprange["CidrIp"])
                                in_network |= net.include?(public_ip)
                            end
                            in_network
                        end
                        # if no matching rule is found, fix it
                        if ingress_permission.empty?
                            machine.ui.detail "... #{rule[:description]} (#{rule[:port]} over #{rule[:protocol].to_s})"
                            rule_string = "FromPort=#{port},ToPort=#{port},IpProtocol=#{protocol},IpRanges=[{CidrIp='#{public_ip}/32',Description='#{description} (#{hostname})'}]"
                            stdout, stderr, status = call(:ec2, "authorize-security-group-ingress", {
                                "group-id" => minicoin_group_id,
                                "ip-permissions" => "\"#{rule_string}\""
                            })
                            # don't throw, just warn and continue
                            machine.ui.warn "Failed to add ingress rule for port #{port}: #{stderr}" if status != 0
                        end
                    end
                rescue => e
                    machine.ui.error e
                    raise "The AWS account does not meet the minicoin requirements"
                end
                nil
            end

            def auto_shutdown(machine)
                stdout, stderr, status = call(:cloudwatch, "put-metric-alarm", {
                    "alarm-name" => "#{machine.name}-auto-shutdown",
                    "alarm-description" => "Shut down when CPU is idle for >= 60 minutes",
                    "metric-name" => :CPUUtilization,
                    :namespace => "AWS/EC2",
                    :period => 60,                                  # sample every minute
                    "evaluation-periods" => 60,                     # if of the 60 last checks
                    "datapoints-to-alar" => 60,                     # for all 60
                    :statistic => :Maximum,                         # the max CPU usage
                    "comparison-operator" => :LessThanThreshold,    # was never above
                    :threshold => 20,                               # 20%
                    :unit => :Percent,
                    "alarm-action" => "arn:aws:swf:#{@@default_region}:#{@@aws_account}:action/actions/AWS_EC2.InstanceId.Stop/1.0",
                    "dimensions" => "Name=InstanceId,Value=#{machine.id}"
                })
                if status != 0
                    machine.ui.warn "Failed to set up auto-shutdown alarm in cloudwatch: #{stderr}"
                else
                    machine.ui.detail "Auto-shutdown enabled"
                end
            end
        end
    end
end

# AWS specific settings
def aws_setup(box, machine)
    $settings[:aws_boxes] ||= []

    return unless Vagrant.has_plugin?('vagrant-aws')
    return unless VagrantPlugins::AWS::Provider::check_cli()
    # We need to somehow communicate the admin password to the machine's vagrant file,
    # and using an environment variable (or alternatively $settings) seems to be the only way,
    # and we want users to set the admin password for the machines anyway.
    aws_password = ENV['AWS_VM_ADMIN_PASSWORD'] || "#(#{ENV['minicoin_key']})"

    # this has to happen on machine level, even though it's only needed for the
    # provider, otherwise the plugin runs after machine-level provisioners, which
    # is too late.
    box.vm.synced_folder "", "/aws", type: :cloud_prepare, id: :aws, admin_password: aws_password

    box.vm.provider :aws do |aws, override|
         # this group is created by minicoin with permissions for SSH, RDP, and WinRM
        aws.security_groups = [ "minicoin" ]

        # Workaround for https://github.com/mitchellh/vagrant-aws/issues/538: if the box we
        # want is not installed yet, then the AWS plugin fails the validation before the box
        # gets downloaded and installed. To check whether the box is installed, we use an entry
        # in our global settings hash that boxes add themselves to via their Vagrantfile.
        # If the box is not loaded yet, then setting the ami to a dummy value satisfies the
        # plugin without overwriting the box file or the AWS-specific provisioning declared
        # in the minicoin machine configuration.
        aws.ami = "dummy" unless $settings[:aws_boxes].include?(box.minicoin.machine['box'])

        aws.tags = {
            "minicoin" => box.minicoin.machine['name']
        }

        # We expect that the user has a key pair in ~/.ssh
        begin
            public_key = File.read("#{$HOME}/.ssh/id_rsa.pub").strip
            override.ssh.private_key_path = "~/.ssh/id_rsa"
            override.winssh.private_key_path = "~/.ssh/id_rsa"
        rescue => e
            STDERR.puts "Failed to read the public key: #{e}"
        end

        # as configured
        aws.region = VagrantPlugins::AWS::Provider.default_region()

        user_data_file = "linux"
        user_data_file = box.vm.guest.to_s if box.vm.guest.is_a?(Symbol)
        begin
            user_data = File.read("./lib/cloud_provision/aws/#{user_data_file}.user_data").strip
            user_data.sub!('#{public_key}', public_key)
            user_data.sub!('#{aws_password}', aws_password)
            aws.user_data = user_data
        rescue => e
            STDERR.puts "Failed to read user data for AWS platform #{user_data_file}"
        end

        # destroying an instance is broken in the vagrant plugin, so we
        # always terminate when the instance is shut down via `vagrant halt`
        aws.terminate_on_shutdown = true

        # disable all folder sharing, it makes no sense for a machine in the cloud
        override.vm.synced_folder ".", "/opt/minicoin", disabled: true
        shared_folder = box.minicoin.actual_shared_folders
        shared_folder.each do |host, guest|
            override.vm.synced_folder host, guest, disabled: true
        end

        # the default user in the VM is not vagrant, so we have to set that explicitly
        override.ssh.username = "vagrant"
        override.winrm.username = "vagrant"
        override.winrm.password = aws_password

        # prevent session timeouts
        override.ssh.keep_alive = true
        override.winssh.keep_alive = true

        # don't allow plain text authentication to a cloud provider
        override.winrm.transport = :negotiate
        override.winrm.basic_auth_only = false
        override.winrm.timeout = 3600
        override.winrm.ssl_peer_verification = false

        override.vagrant.sensitive = [ aws_password ]
    end
end
