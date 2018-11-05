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

1. Install jinja2 version 2.8, newer versions have still bugs in ansible.
    ```sh
    pip install jinja2=2.8 --user
    ```
1. Install ansible version 2.7
    ```sh
    pip install ansible==2.7 --user
    ```
1. Symlink playbooks 
    ```sh
    ln -s /path/to/playbooks playbooks
    ```
1. Configure ansible-vault password path (vault_password_file) in ansible.cfg.

Vagrant is ready to run, see a list of configured boxes
with `vagrant status`. IPs will be assigned on first run (in ip_mapping.json).

Optionally generate a hosts file with `./inventory.rb --hosts`. If using this, keep hosts.base up
to date.
