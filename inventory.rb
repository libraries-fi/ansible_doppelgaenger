#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'ipaddr'
require 'fileutils'
require 'pathname'

# Use property 'vagrant_synced_folders' in inventory.yml to specify
# list of synced folders for each host.
# If it is missing use default /srv/sites folder.
SyncedFolderConfig = Struct.new(:name, :path)
DEFAULT_SYNCED_FOLDER = SyncedFolderConfig.new("sites", "/srv/sites")
SYNCED_FOLDERS_BASE = Pathname("shared")

# Sets the development IP addresses in host vars overriding previous values.
def set_ips(ip_mapping, inventory)
  ip_mapping.each do |dev_host, settings|

    if ! inventory["_meta"]["hostvars"].key?(dev_host)
      inventory["_meta"]["hostvars"][dev_host] = {}
    end

    inventory["_meta"]["hostvars"][dev_host]["ansible_ssh_host"] = settings["ansible_ssh_host"]
  end
  inventory
end

# Rename hosts in hostvars for development.
def get_hostvars(inventory)
  new_hostvars = {}
  inventory["_meta"]["hostvars"].each do |hostname, vars|
    new_hostvars[hostname + ".local"] = vars
  end
  new_hostvars
end

# Rename hosts in groups for development.
def set_hostnames(inventory)
  inventory.each do |key, value|
    if value.key?("hosts") && value["hosts"] != []
      hosts = []
      value["hosts"].each do |host|
        hosts.push(host + ".local")
      end
      inventory[key]["hosts"] = hosts
    end
  end
  inventory
end

def configure_synced_folders(vm_config, hostname, config)
  synced_folders_host = SYNCED_FOLDERS_BASE + hostname
  synced_folders = config
    .fetch("vagrant_synced_folders", [])
    .map! { |c| SyncedFolderConfig.new(c["name"], c["path"]) }

  # Move synced files to a new setup, where there can be multiple synced folders in
  # subdirectories inside shared/hostname. Check that this is first time running after shared
  # folder layout change and vagrant_synced_folders option in not yet used.
  # NOTE: This can be deleted when all files have been moved.
  if synced_folders.empty?
    default = synced_folders_host + DEFAULT_SYNCED_FOLDER.name

    if !default.directory? && synced_folders_host.directory? &&
        !synced_folders_host.children(false).empty?
      puts "inventory.rb: Moving old synced files to a new directory!"
      to_move = synced_folders_host.children
      FileUtils.mkdir(default)
      FileUtils.mv(to_move, default)
    end
  end

  synced_folders = [DEFAULT_SYNCED_FOLDER] if synced_folders.empty?

  synced_folders.each do |synced_folder|
    synced_folder_vm = Pathname(synced_folder.path)

    vm_config.vm.synced_folder(
      (synced_folders_host + synced_folder.name).to_s,
      synced_folder_vm.to_s,
      create: true,
      owner: "vagrant",
      group: "www-data",
      mount_options: ["dmode=775,fmode=664"]
    )
  end
end

def define_vagrant_vms(vagrant_config)
  inventory = create_dev_inventory

  inventory["_meta"]["hostvars"].each do |hostname, config|
    vagrant_config.vm.define hostname do |vm_config|
      vm_config.vm.hostname = hostname
      vm_config.vm.network "private_network", ip: config["ansible_ssh_host"]
      configure_synced_folders(vm_config, hostname, config)
      if config.key?("vagrant_box")
        vm_config.vm.box = config["vagrant_box"]
      end
    end
  end
end

def generate_hosts_file()
  if ! File.file? "hosts.base"
    FileUtils.cp "/etc/hosts", "hosts.base"
  end

  hosts = File.read("hosts.base")
  inventory = create_dev_inventory
  inventory["vagrant"]["hosts"].each do |hostname, value|
    hosts += inventory["_meta"]["hostvars"][hostname]["ansible_ssh_host"] + " " + hostname + "\n"
  end
  hosts
end

def save_ip_mapping(hosts_to_add, ip, ip_mapping)
  # assign ips for hosts that are missing.
  hosts_to_add.each do |host|
    ip_mapping[host] = {"ansible_ssh_host" =>  ip.to_s}
    ip = ip.succ
  end

  # Write the inventory file if there are ip changes to save.
  if hosts_to_add != []
    File.write("ip_mapping.json", JSON.pretty_generate(ip_mapping))
  end
end

def load_ip_mapping()
  if File.file? "ip_mapping.json"
    ip_mapping = JSON.parse File.read("ip_mapping.json")
  end

  if ! ip_mapping
    ip_mapping    = {}
  end
  ip_mapping
end

def find_new_hosts_and_max_ip(inventory, ip_mapping)
  ip = IPAddr.new "192.168.33.3"

  # get a list of hosts that have to be added to ip_mapping and the highest currently assigned ip.
  hosts_to_add = []
  inventory.each do |key, value|
    if value.key?("hosts") && value["hosts"] != []
      value["hosts"].each do |host|
        if ! ip_mapping.key?(host)
          hosts_to_add.push(host)
        else
          used_ip = IPAddr.new ip_mapping[host]["ansible_ssh_host"]
          if used_ip > ip
            ip = used_ip
          end
        end
      end
    end
  end
  [ip, hosts_to_add]
end

def convert_json_to_yaml(inventory)
  inventory.each do |group, content|
    ["hosts", "children"].each do |field|
      if content.key?(field)
        if content[field] == []
          content.delete(field)
        else
          content[field] = Hash[content[field].map{ |a| [a, nil] }]
        end
      end
    end
  end

  inventory.each do |group, content|
    if content.key?("hosts")
      content["hosts"].each do |hostname, settings|

        if inventory["_meta"]["hostvars"].key?(hostname)
          content["hosts"][hostname] = inventory["_meta"]["hostvars"][hostname]
          inventory["_meta"]["hostvars"].delete(hostname)
        end
      end
    end
  end
  inventory.delete("_meta")
  File.write("inventory.yaml", inventory.to_yaml)
end

def convert_yaml_to_json(inventory)
  # Create the meta entry.
  inventory["_meta"] = {"hostvars" => {} }
  inventory.each do |group, content|

    if content.key?("hosts")
      content["hosts"].each do |hostname, settings|
        if settings != nil
          inventory["_meta"]["hostvars"][hostname] = settings
        end
      end
    end
  end

  # Change hashes to arrays
  inventory.each do |group, content|
    ["hosts", "children"].each do |field|
      if content.key?(field)
        content[field] = content[field].keys
      end
      end
    end
  inventory
end

def create_vagrant_group(inventory)
  inventory["vagrant"] = {"hosts" => []}
  inventory.each do |key, value|
    if value.key?("hosts") && value["hosts"] != []
      inventory["vagrant"]["hosts"] += value["hosts"]
    end
  end
end

def get_all_inventory_hosts(inventory)
  hosts = []
  inventory.each do |key, value|
    if value.key?("hosts") && value["hosts"] != []
      hosts += value["hosts"]
    end
  end
  hosts
end

def get_hostvars_for_production(production_hosts)
  hostvars = {}
  production_hosts.each do |host|
    hostvars[host] = {"ansible_ssh_user" => "root"}
  end
  hostvars
end

def create_dev_inventory()
  if ! File.file? "playbooks/inventory.yaml"
    puts "Inventory not found."
    exit 1
  end

  inventory = YAML.load File.read("playbooks/inventory.yaml")
  inventory = convert_yaml_to_json(inventory)
  ip_mapping = load_ip_mapping

  ip, hosts_to_add = find_new_hosts_and_max_ip(inventory, ip_mapping)
  save_ip_mapping(hosts_to_add, ip, ip_mapping)

  production_hosts = get_all_inventory_hosts(inventory)
  inventory = set_ips(ip_mapping, inventory)
  inventory = set_hostnames(inventory)
  inventory["_meta"]["hostvars"] = get_hostvars(inventory)
  create_vagrant_group(inventory)

  if ! inventory.key?("ungrouped") || ! inventory["ungrouped"].key?("hosts")
    inventory["ungrouped"] = {"hosts" => [] }
  end
  inventory["ungrouped"]["hosts"] += production_hosts

  inventory["_meta"]["hostvars"].merge!(get_hostvars_for_production(production_hosts))
  inventory
end

def main()
  inventory = create_dev_inventory
  #  convert_json_to_yaml(inventory)

  if ARGV[0] != '--hosts'
    print JSON.pretty_generate(inventory)
  else
    print generate_hosts_file()
  end
end

if __FILE__ == $0
  main
end
