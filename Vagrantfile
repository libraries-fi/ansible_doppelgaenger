# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

require_relative "inventory"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  define_vagrant_vms config
  config.ssh.forward_agent = true
  config.ssh.insert_key = false
  # Disable /vagrant folder syncing, it takes a lot of space on vm.
  config.vm.synced_folder '.', '/vagrant',
    disabled: true,
    id: "vagrant-root"
  config.vm.box = "debian/wheezy64"

  config.vm.provider :libvirt do |libvirt|
    libvirt.memory = 1024
  end

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbooks/site.yml"
    # ansible.verbose = 'vvvv'
    ansible.inventory_path = 'inventory.rb'
    ansible.become = true
    ansible.skip_tags = ['production_only', 'fail2ban']
    ansible.host_key_checking = false
    ansible.raw_ssh_args = ['-o UserKnownHostsFile=/dev/null']
    ansible.force_remote_user = false
    ansible.extra_vars = {
      file_sync_no_controlhost: 'True',
    }
  end
end
