# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

require_relative "inventory"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  define_vagrant_vms config
  config.ssh.forward_agent = true
  config.ssh.insert_key = false
  config.vm.box = "debian/wheezy64"

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbooks/site.yml"
    # ansible.verbose = 'vvvv'
    ansible.inventory_path = 'inventory.rb'
    ansible.sudo = true
    ansible.skip_tags = ['production_only']
    ansible.host_key_checking = false
    ansible.raw_ssh_args = ['-o UserKnownHostsFile=/dev/null']
    ansible.extra_vars = { ansible_ssh_user: 'vagrant',
                           site_content_sync: 'True',
                           file_sync_no_controlhost: 'True',
                         }
  end
end
