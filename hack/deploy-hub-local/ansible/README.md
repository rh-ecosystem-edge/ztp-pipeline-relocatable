# Hypervisor Setup

## Purpose

Use this playbooks to setup or update the hypervisor where you want to deploy ZTPFW using the pipelines contained on this repository.

setup.yaml will make the hypervisor ready for the pipelines to run.
upgrade.yaml will upgrade the hypervisor to the latest packages.

## Inventory

```yaml
all:
  vars:
    # Ansible local variables
    ansible_connection: ssh
    ansible_ssh_user: root
    # ansible_verbosity:
    # ansible_run_tags:
    # ansible_skip_tags:

    # Hosts default variables
    # Override if needed in Hosts inventory
    console_keymap: en
    console_font: eurlatgr
    system_locale: en_US.UTF-8
    system_timezone: Europe/Madrid
    domain: "{{ ansible_nodename.split('.')[1:] | join('.') }}"
    ns_int1: "8.8.8.8"
    ns_int2: "8.8.4.4"
    ns_ext1: "8.8.8.8"
    ns_ext2: "8.8.4.4"
    network_type: none
    pkg_manager: "dnf"

    # Root random password
    root_update_pwd: False
    root_password: "PROVIDE-A-PASSWORD-SALT"
    root_shell: /bin/bash
    
    # Motd user
    motd_user: "ZTPFW Ansible Playbooks"

    # SSH configuration
    ssh_configure: True
    ssh_keys_update: True
    ssh_keys_users:
      - iranzo
      - alknopfler
      - jparrill
      - flaper87
      - DirectedSoul1
      - eifrach
      - danielchg
      - fbac

    # Tuned configuration
    tuned_configure: True
    tuned_profile: latency-performance

    # Chronyd configuration
    chronyd_configure: True

    # Journal
    journal_SystemMaxUse: 500M

    # Logrotate
    logrotate_configure: True

  # Hosts inventory
  children:
    local:
      hosts:
        ansible-vm-target:
          ansible_host: 127.0.0.1
          vars:
            pkg_manager: dnf
    ztp:
      hosts:
        fakenode1.external.io:
        fakenode2.external.io:
        fakenodeN.external.io:
```

## Usage

### Variables

This variables control the final configuration delivered by the playbooks.

They can be used in the inventory as global variables or be set independently per node(s).

> - **console_keymap**: keymap to use in the console (Default: en).
> - **console_font**: font to use in the console (Default: eurlatgr).
> - **system_locale**: system locales (Default: en_US.UTF-8).
> - **system_timezone**: system timezone (Default: Europe/Madrid)
> - **domain**: domain for the host (Default: {{ ansible_nodename.split('.')[1:] | join('.') }})
> - **ns_int1**: first nameserver in /etc/resolv.conf (Default: 8.8.8.8)
> - **ns_int2**: second nameserver in /etc/resolv.conf (Default: 8.8.4.4)
> - **ns_ext1**: first nameserver in /etc/resolv.upstream.conf (Default: 8.8.8.8)
> - **ns_ext2**: second nameserver in /etc/resolv.upstream.conf (Default: 8.8.4.4)
> - **network_type**: Accepted values: none, external, internal. Will run the lab-dns-internal.sh or lab-dns-external.sh 
> - **pkg_manager**: package manager used by the system (Default: dnf)
> - **root_update_pwd**: Wether or not upgrade the root password with the provided one (Default: False)
> - **root_password**: root password in salt format
> - **root_shell**: Default shell for root (Default: /bin/bash)
> - **motd_user**: User to be shown in /etc/motd. Just an aesthetic feature. (Default: ZTPFW Ansible Playbooks )
> - **ssh_configure**: Wether or not configure sshd (Default: True)
> - **ssh_keys_update**: Wether or not update the /root/.ssh/authorized_keys (Default: True)
> - **ssh_keys_users**: Array of users whose ssh keys will be retrieved from github and added to the node.
> - **tuned_configure**: (Default: True)
> - **tuned_profile**: Profile to be used by tuned (Default: latency-performance)
> - **chronyd_configure**: Wether or not configure chronyd (Default: True)
> - **journal_SystemMaxUse**: Maximum retention for journald logs (Default: 500M)
> - **logrotate_configure**: Wether or not configure logrotate (Default: True)

### Tags

Multiple tags are provided to control the playbook's behavior.

These tasks can be invoked from command-line or configured in the inventory through the **ansible_run_tags** and **ansible_skip_tags** variables.

> - **00-base-os**: Base configuration, including cleaning the system, changing root password, root .bashrc, root default shell, etc.
> - **00-base-network**: Base network configuration, it will run dns scripts if network_type is set to external or internal
> - **00-common-services**: Common services enabled by default
> - **01-configure-dnf**: Configure DNF, install EPEL and enable copr/karmab
> - **01-packages**: Install common useful packages
> - **02-bin-utils**: Install ztp repository and build set-motd
> - **configure-chronyd**: Configure chronyd daemon
> - **configure-libvirtd**: Configure libvirtd
> - **configure-logrotate**: Configure logrotate
> - **configure-sshd**: Configure sshd
> - **configure-tuned**: Configure tuned

### Examples

> Run setup.yaml against all hosts in the inventory

```bash
ansible-playbook -i path/to/inventory setup.yaml
```

> Run setup.yaml against one specific host

```bash
ansible-playbook -i path/to/inventory -l host-dummy setup.yaml
```

> Run only tasks with the label 02-bin-utils in one specific host

```bash
ansible-playbook -i path/to/inventory --tags 02-bin-utils -l host-dummy setup.yaml
```

> Run setup.yaml, skipping tags related to dns configuration

```bash
ansible-playbook -i path/to/inventory --skip-tags 00-base-dns -l host-dummy setup.yaml 
```

> Run setup.yaml, only the tags related to base configuration, skipping those related to bin-utils

```bash
ansible-playbook -i path/to/inventory --tags 00-base --skip-tags 02-bin-utils -l host-dummy setup.yaml
```

#### WIP - Technical debt braindump

```bash
Create root id_rsa
Install github agent
crontab logrotate
slack notifications on completion
```
