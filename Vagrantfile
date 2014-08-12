VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |vconfig|
  vconfig.vm.define :HabitatBase do |config|

	# Configure The Box
	config.vm.box = "ubuntu/trusty64"
	config.vm.hostname = "habitat.dev"
#config.vm.box_check_update = false
	config.vm.network :private_network, ip: "192.168.33.10"

	config.vm.provider "virtualbox" do |vb|
	  vb.customize ["modifyvm", :id, "--memory", "2048"]
	  vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
	  vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
	end

	# Configure Port Forwarding
	config.vm.network "forwarded_port", guest: 80, host: 8000
	config.vm.network "forwarded_port", guest: 3306, host: 33060
	config.vm.network "forwarded_port", guest: 5432, host: 54320

	# Run The Base Provisioning Script
	config.vm.provision "shell" do |s|
	  s.path = "./scripts/provision.sh"
	end
  end
end