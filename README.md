ansible_doppelgaenger
==========

Description
------------
Vagrant configuration that includes a (quickly hacked together) dynamic inventory script,
vagrant vm definition helper and a hosts generator. This enables bringing up a development
duplicate of any host in the production inventory with Vagrant and keeps the same locally
defined IPs that can also be written to /etc/hosts if needed. Requires the ansible inventory to be
in YAML format.

Usage
-------------
Symlink playbooks like "ln -s /path/to/playbooks playbooks". Vagrant is ready to run, see a list
of configured boxes with "vagrant status". IPs will be assigned on first run (in ip_mapping.json).

Optionally generate a hosts file with "./inventory.rb --hosts". If using this, keep hosts.base up
to date.