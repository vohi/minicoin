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
            def self.call(service, method, json={})
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
                Open3.capture3("#{cli()} #{service} #{method} #{params}")
            end

            def self.cli()
                return @@aws_cli if @@tried_cli
                @@tried_cli = true
                @@aws_cli ||= Which.which("aws")
            end
            def self.default_region()
                @@default_region ||= `#{cli()} configure get region`.strip
            end
            def self.keypair()
                return @@keypair if @@keypair
                stdout, stderr, status = Provider.call("ec2", "describe-key-pairs", {
                    "key-names" => "minicoin"
                })
                if status == 0
                    keypairs = JSON.parse(stdout)
                    keypairs.each do |keypair|
                        # ['keypairs', [{"KeyPairId" => "..."}]]
                        @@keypair = keypair[1][0]
                    end
                end
                @keypair ||= {}
            end

            def prepare_account(machine)
                return nil unless @@aws_account.nil?
                return unless ['up', 'validate'].include?(ARGV[0]) # don't check AWS for check and shutdown operations
                begin
                    @@aws_account = "" # don't try again
                    # check that there are credentials
                    stdout, stderr, status = Provider.call(:sts, "get-caller-identity")
                    raise "Failed to read AWS account information" if status != 0
                    aws_profile = JSON.parse(stdout)
                    @@aws_account = aws_profile['Account']
                    machine.ui.info "Verifying AWs account #{@@aws_account}"

                    # verify that there is a default VPC
                    stdout, stderr, status = Provider.call(:ec2, "describe-vpcs", {
                        :filter => { "is-default" => true, "state" => "available"}
                    })
                    raise "Failed to read VPC information: #{stderr}" if status != 0
                    default_vpc = JSON.parse(stdout)['Vpcs'][0]
                    raise "No available default VPC found" if default_vpc.nil?
                    machine.ui.detail "Using Virtual private cloud #{default_vpc['VpcId']}"

                    # check if there's a minicoin security group, and create it if not
                    stdout, stderr, status = Provider.call(:ec2, "describe-security-groups", {
                        :filters => {
                            "group-name" => "minicoin",
                            "vpc-id" => default_vpc['VpcId']
                        }
                    })
                    raise "Failed to read security group information: #{stderr}" if status != 0
                    minicoin_group = JSON.parse(stdout)['SecurityGroups'][0]
                    if minicoin_group.nil?
                        machine.ui.detail "minicoin security group not found, creating..."
                        stdout, stderr, status = Provider.call(:ec2, "create-security-group", {
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
                            stdout, stderr, status = Provider.call(:ec2, "authorize-security-group-ingress", {
                                "group-id" => minicoin_group_id,
                                "ip-permissions" => "\"#{rule_string}\""
                            })
                            # don't throw, just warn and continue
                            machine.ui.warn "Failed to add ingress rule for port #{port}: #{stderr}" if status != 0
                        end
                    end
                    
                    unless (Provider.keypair() || {}).empty?
                        machine.ui.detail "Key pair '#{@@keypair['KeyPairId']}' with fingerprint #{@@keypair['KeyFingerprint']} found"
                    end
                rescue => e
                    if ['validate'].include?(ARGV[0]) # errors as warnings for validation runs
                        machine.ui.warn e
                    else
                        machine.ui.error e
                        raise "The AWS account does not meet the minicoin requirements"
                    end
                end
                nil
            end

            def auto_shutdown(machine)
                provider_settings = Minicoin.get_config(machine).machine["provider"] || {}
                auto_shutdown = (provider_settings["aws"] || {})["auto_shutdown"]
                return if auto_shutdown.nil? || auto_shutdown == 0
                machine.ui.detail "Enabling auto-shutdown after #{auto_shutdown} minutes of low CPU usage"
                stdout, stderr, status = Provider.call(:cloudwatch, "put-metric-alarm", {
                    "alarm-name" => "#{machine.name}-auto-shutdown",
                    "alarm-description" => "Shut down when CPU is idle for >= #{auto_shutdown} minutes",
                    :namespace => "AWS/EC2",
                    :period => 60,                                  # sample every minute
                    "evaluation-periods" => auto_shutdown,          # set alarm if for all samples
                    "datapoints-to-alarm" => auto_shutdown,
                    :statistic => :Maximum,                         # the max
                    "metric-name" => :CPUUtilization,               # CPU usage
                    "comparison-operator" => :LessThanThreshold,    # was never above
                    :threshold => 20,                               # 20%
                    :unit => :Percent,
                    "alarm-action" => "arn:aws:swf:#{Provider.default_region()}:#{@@aws_account}:action/actions/AWS_EC2.InstanceId.Stop/1.0",
                    "dimensions" => "Name=InstanceId,Value=#{machine.id}"
                })
                machine.ui.warn "Failed to set up auto-shutdown alarm in cloudwatch: #{stderr}" if status != 0
            end

            def open_gui(vm, start_command)
                if vm.state.id != :running
                    vm.ui.error "The instance isn't running: #{vm.state.id}"
                    return
                end
                socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
                vnc_port = 5900
                vnc_host = vm.ssh_info[:host]
                runs_vnc = false
                vm.ui.info "Testing VNC connection"

                begin
                    address = Socket.sockaddr_in(vnc_port, vnc_host)
                    socket.connect_nonblock(address)
                rescue Errno::EINPROGRESS
                    if IO.select(nil, [socket], nil, 1)
                        begin
                            socket.connect_nonblock(address)
                        rescue Errno::EISCONN
                            runs_vnc = true
                        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                            runs_vnc = false
                        end
                    end
                end

                if runs_vnc
                    vm.ui.detail "Address: #{vnc_host}:#{vnc_port}"
                    o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map(&:to_a).flatten
                    password = (0...10).map { o[rand(o.length)] }.join
                    begin
                        vm.communicate.sudo("x11vnc -storepasswd #{password} /etc/x11vnc.pwd")
                        vm.ui.success "Machine runs VNC; minicoin will now launch your VNC client with the"
                        vm.ui.success "connection parameters above."
                        vm.ui.success "The VNC password for this session will be: #{password}"
                        `#{start_command} vnc://#{vm.ssh_info[:host]}`
                    rescue
                        vm.ui.error "Couldn't write VNC password!"
                    end
                end
                runs_vnc
            end

        private
            @@tried_cli = nil
            @@aws_cli = nil
            @@aws_account = nil
            @@default_region = nil
            @@public_key = nil
            @@keypair = nil
        end
    end
end

module Minicoin
    module AWSExtensions
        class Plugin < Vagrant.plugin("2")
            name "Minicoin extensions for AWS"
            def self.minicoin_extension(provider)
                Extension if provider == :aws
            end
            # AWS specific settings
            def self.minicoin_setup(box, machine)
                $settings[:aws_boxes] ||= []

                return unless Vagrant.has_plugin?('vagrant-aws')
                return unless VagrantPlugins::AWS::Provider::cli()
                # We need to somehow communicate the admin password to the machine's vagrant file,
                # and using an environment variable (or alternatively $settings) seems to be the only way,
                # and we want users to set the admin password for the machines anyway.
                aws_password = ENV['AWS_VM_ADMIN_PASSWORD'] || "#(#{ENV['minicoin_key']})" || "$Vagrant(0)"

                # this has to happen on machine level, even though it's only needed for the
                # provider, otherwise the plugin runs after machine-level provisioners, which
                # is too late.
                box.vm.synced_folder "", "/aws", type: :cloud_prepare, id: :aws, admin_password: aws_password

                box.vm.provider :aws do |aws, override|
                    # this group is created by minicoin with permissions for SSH, RDP, and WinRM
                    aws_profile = ENV[ "AWS_PROFILE"]
                    aws.aws_profile = aws_profile if aws_profile
                    aws.security_groups = [ "minicoin" ]
                    keypair = VagrantPlugins::AWS::Provider::keypair()
                    aws.keypair_name = keypair['KeyName'] unless keypair.nil? || keypair.empty?

                    # Workaround for https://github.com/mitchellh/vagrant-aws/issues/538: if the box we
                    # want is not installed yet, then the AWS plugin fails the validation before the box
                    # gets downloaded and installed. To check whether the box is installed, we use an entry
                    # in our global settings hash that boxes add themselves to via their Vagrantfile.
                    # If the box is not loaded yet, then setting the ami to a dummy value satisfies the
                    # plugin without overwriting the box file or the AWS-specific provisioning declared
                    # in the minicoin machine configuration.
                    aws.ami = "dummy" unless $settings[:aws_boxes].include?(box.minicoin.machine['box'])

                    aws.tags = {
                        "minicoin" => box.minicoin.machine['name'],
                        "Name" => box.minicoin.machine['name']
                    }

                    # We expect that the user has a key pair in ~/.ssh
                    begin
                        @@public_key ||= File.read("#{$HOME}/.ssh/id_rsa.pub").strip
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
                        user_data.sub!('#{public_key}', @@public_key)
                        user_data.sub!('#{aws_password}', aws_password)
                        aws.user_data = user_data
                    rescue => e
                        STDERR.puts "Failed to read user data for AWS platform #{user_data_file}"
                    end

                    # we want to be able to automatically stop the instance from inside via `shutdown`
                    # but we don't want it to be terminated.
                    aws.terminate_on_shutdown = false

                    # disable all folder sharing, it makes no sense for a machine in the cloud
                    override.vm.synced_folder ".", "/opt/minicoin", disabled: true
                    shared_folder = box.minicoin.default_shared_folders
                    shared_folder.each do |host, guest|
                        override.vm.synced_folder host, guest, disabled: true
                    end

                    if machine["storage"]
                        value = machine["storage"]
                        # all storage entries become EBS volumes, so start with /dev/sdf
                        storage_device = 'f'
                        value = [value] unless value.is_a?(Array)
                        block_device_mappings = []
                        attached_volumes = []
                        value.each do |storage|
                            block_device = {}
                            device_name = "/dev/sd#{storage_device}"
                            if storage.is_a?(Hash)
                                if storage["volume"]
                                    attached_volumes << {
                                        "volume-id" => storage['volume'],
                                        "device" => device_name
                                    }
                                else
                                    block_device["DeviceName"] = storage["device"] || device_name
                                    block_device["Ebs.VolumeSize"] = storage["size"] if storage["size"]
                                    block_device["Ebs.DeleteOnTermination"] = storage["deleteOnTermination"] if storage["deleteOnTermination"]
                                    block_device["Ebs.SnapshotId"] = storage["snapshot"] if storage["snapshot"]
                                end
                                storage_device.next! unless storage.has_key?("DeviceName")
                            else
                                block_device["Ebs.VolumeSize"] = storage
                                block_device["DeviceName"] = device_name
                                storage_device.next!
                            end
                            block_device_mappings << block_device unless block_device.empty?
                        end
                        unless attached_volumes.empty?
                            attach_volumes = lambda do |machine|
                                attached_volumes.each do |volume|
                                    machine.ui.detail "Attaching #{volume['volume-id']} as #{volume['device']}"
                                    volume["instance-id"] = machine.id
                                    stdout, stderr, status = machine.provider.class.call(:ec2, "attach-volume", volume)
                                    machine.ui.error "Error attaching volume #{volume['volume-id']}: #{stderr}" if status != 0
                                end
                            end
                            override.vm.provision "attach-volume",
                                type: :local_command,
                                code: attach_volumes
                        end
                        aws.block_device_mapping = block_device_mappings unless block_device_mappings.empty?
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

                    override.vagrant.sensitive = [ aws_password, @@public_key ]
                end
            end
        end

        class Extension
            def provision(box, name, args, machine)
                return if args.nil?
                raise "Argument error: aws provider configuration needs to be a hash" unless args.is_a?(Hash)
                box.vm.provider :aws do |aws, override|
                    args.each do |key, value|
                        case key
                        when "region_config"
                            raise "Argument error: region_config needs to be a hash" unless value.is_a?(Array)
                            value.each do |region_config|
                                raise "Argument error: each region_config needs to be a hash 'name => {...}'" unless region_config.is_a?(Hash)
                                region_config.each do |name, settings|
                                    aws.region_config "#{name}" do |region|
                                        if value.is_a?(Array) || value.is_a?(Hash)
                                            eval("region.#{key} = #{value}")
                                        else
                                            eval("region.#{key} = \"#{value}\"")
                                        end
                                    end
                                end
                            end
                        when "auto_shutdown"
                            # do nothing yet, this is handled in the cloud_prepare code
                        else
                            if value.is_a?(Array) || value.is_a?(Hash)
                                eval("aws.#{key} = #{value}")
                            else
                                eval("aws.#{key} = \"#{value}\"")
                            end
                        end
                    end
                end
            end
        end
    end
end
