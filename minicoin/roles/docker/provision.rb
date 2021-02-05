def docker_provision(box, name, role_params, machine)
  detach = true
  restart = "always"

  docker = role_params["docker"]
  image = role_params["image"]
  cmd = role_params["cmd"]
  args = role_params["args"]
  detach = (role_params["detach"] == true) unless role_params["detach"].nil?
  restart = role_params["restart"] unless role_params["restart"].nil?
  box.vm.provision "#{name}:docker container",
    type: :docker do |docker|
      docker.run docker,
      image: image,
      cmd: cmd,
      auto_assign_name: false,
      args: args,
      daemonize: detach,
      restart: restart
    end
end
