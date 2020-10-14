def hostscript_provision(box, name, args)
    if preprovision = args["preprovision"]
        box.trigger.before [:up, :provision] do |trigger|
            trigger.name = "postprovisioning hostscript"
            trigger.run = {
                inline: preprovision
            }
        end
    end
    if postprovision = args["postprovision"]
        box.trigger.after [:up, :provision] do |trigger|
            trigger.name = "postprovisioning hostscript"
            trigger.run = {
                inline: postprovision
            }
        end
    end
end