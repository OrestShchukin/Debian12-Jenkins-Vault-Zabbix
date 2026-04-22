Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.hostname = "devops-lab"

  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "devops-lab"
    vb.memory = 4096
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "provision/bootstrap.sh"
end