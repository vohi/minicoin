def aws_provision(box, name, args, machine)
    raise "Argument error: aws provider configuration needs to be a hash" unless args.is_a?(Hash)
    box.vm.provider :aws do |aws, override|
        args.each do |key, value|
            case key
            when "storage"
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
                    box.vm.provision "attach-volume",
                        type: :local_command,
                        code: attach_volumes
                end
                aws.block_device_mapping = block_device_mappings unless block_device_mappings.empty?
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
