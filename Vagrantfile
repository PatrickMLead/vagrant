Vagrant.configure("2") do |config|

  # master server
  config.vm.define "master" do |master|
    master.vm.box = "generic/ubuntu2204"
    # master.ssh.insert_key = true
    master.vm.hostname = "master"
    master.vm.network :private_network, ip: "192.168.56.10"
    master.vm.provider :virtualbox do |vb|
     # vb.customize ["startvm", :id, "--type", "headless"]
      # vb.linked_clone = true
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--memory", "2048"]
      vb.customize ["modifyvm", :id, "--name", "master"]
      vb.customize ["modifyvm", :id, "--cpus", "2"]
    end
    # config.vm.provision "shell", inline: <<-SHELL
    #   sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    #   service ssh restart
    # SHELL
     config.vm.provision "shell", path: "install_common.sh"
    # config.vm.provision "shell", path: "install_master.sh"
  end

  # slave server
  numbrSrv=2
  (1..numbrSrv).each do |i|
    config.vm.define "worker#{i}" do |slave|
      slave.vm.box = "generic/ubuntu2204"
      slave.vm.hostname = "worker#{i}"
      slave.vm.network "private_network", ip: "192.168.56.1#{i}"
      slave.vm.provider :virtualbox do |vb|
        vb.name = "worker#{i}"
        vb.memory = "2048"
        vb.cpus = "2"
      end
      # config.vm.provision "shell", inline: <<-SHELL
      #   sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
      #   service ssh restart
      # SHELL
       config.vm.provision "shell", path: "install_common.sh"
      # config.vm.provision "shell", path: "install_node.sh"
    end
  end
end
