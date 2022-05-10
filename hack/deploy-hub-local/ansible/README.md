# Hypervisor Setup

## Purpose

Use this playbooks to setup or update the hypervisor where you want to deploy ZTPFW using the pipelines contained on this repository.

setup.yaml will make the hypervisor ready for the pipelines to run.
upgrade.yaml will upgrade the hypervisor to the latest packages.

## Usage

- Setup an inventory

```yaml
all:
  vars:
    ansible_connection: ssh
    ansible_ssh_user: root

    # Default root password: True / False
    updaterootpwd: True
    rootpassword: "$6$e4Nk9dU7W6XyvWqG$xWfb2IbMkyttLfQkpKQivocd1v.NOAGV8pT8YZZEwNZXjvGp2dBhyEPvJ0vcS9JJfkG4d0e1oIJA0VDABG4xL0"

    # SSH
    # Configure SSH: True / False
    # Update SSH authorized keys: True / False
    # Permit password login through SSH: True / False
    configuressh: True
    updatesshkeys: True
    sshpassword: True
    users:
      - iranzo
      - alknopfler
      - jparrill
      - flaper87
      - DirectedSoul1
      - eifrach
      - danielchg
      - fbac

    # Chronyd
    # Configure chronyd: True / False
    configurechronyd: True

    envvar: []
    monit: False

  children:
    core:
      hosts:
        ansible-vm-target:
          ansible_host: 127.0.0.1
      vars:
        os: fedora
    edge:
      hosts:
        node1.fake-edge.ocatopic:
        node2.fake-edge.ocatopic:
      vars:
        os: centos
```

- Run ansible

```bash
ansible-playbook -i path/to/inventory setup.yaml
```

- Force specific variables

```bash
ansible-playbook -i path/to/inventory setup.yaml -e sshpassword=False
```

## Variables

### general

updaterootpwd: change root pwd

### sshd

configuressh:
    - False
    - True

sshpassword:
    - False: disable ssh password login.
    - True: enable ssh password login, this will install and configure fail2ban.

updatesshkeys:
    - False: do not update keys.
    - True: add keys to /root/.ssh/authorized_keys retrieved from "https://github.com/{{ users }}.keys"

### chronyd

configurechronyd: configure chronyd and sync time.

### journald

journalSystemMaxUse: defaults to 500M

## TODO

```bash
Do not use ssh passwords for login, only keys. Requires consensus.
Do not install fail2ban. Requires consensus.
Change variable os to a better suited var
Clone ztp repo at finalizing
Variables to detect internal or external server
Configure dns based on internal/external vars
Create root id_rsa
Install github agent
crontab logrotate
```
