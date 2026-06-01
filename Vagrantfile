# Vagrant configuration for local development
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  config.vm.define "bioshield-dev" do |dev|
    dev.vm.hostname = "bioshield-dev"
    dev.vm.network "private_network", ip: "192.168.56.10"
    dev.vm.network "forwarded_port", guest: 8000, host: 8000
    dev.vm.network "forwarded_port", guest: 9090, host: 9090
    dev.vm.network "forwarded_port", guest: 3000, host: 3000
    
    dev.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = 4
      vb.name = "bioshield-dev"
    end
    
    dev.vm.provision "shell", path: "scripts/install_dependencies.sh"
    dev.vm.provision "shell", inline: "cd /vagrant && ./scripts/deploy.sh development"
  end
  
  config.vm.synced_folder ".", "/vagrant"
end
