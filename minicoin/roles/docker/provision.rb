def docker_provision(vm, role_params)
  detach = true
  restart = "always"

  name = role_params["docker"]
  image = role_params["image"]
  cmd = role_params["cmd"]
  args = role_params["args"]
  detach = (role_params["detach"] == true) unless role_params["detach"].nil?
  restart = role_params["restart"] unless role_params["restart"].nil?
  vm.provision "docker" do |docker|
    docker.run name,
    image: image,
    cmd: cmd,
    auto_assign_name: false,
    args: args,
    daemonize: detach,
    restart: restart
  end
end
