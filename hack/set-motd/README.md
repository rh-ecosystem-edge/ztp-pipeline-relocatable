# set-motd docs

## Usage

Usage: set-motd [set|unset|help]

Set a custom message with the needed flags.

```bash
set [-motd string] [-user string] [-pr link] [-path /foo/bar]
  - motd: set custom message
  - user: set user using the server
  - pr:	set pull-request being tested
  - path: set custom path (Default: /etc/motd)
```

Unset the custom message with `set-motd unset`. This will the server´s motd to "Server free to use".

Show usage with `set-motd help`

## Default values

path: /etc/motd
user: ZTPFW Github Actions

## Default output

```plain
user@localhost]$ ./set-motd set -user fbac -motd "I'm using this server until 2152 at 15:40" -pr https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/pull/249

user@localhost]$  cat /etc/motd

Updated at Wed May 11 15:12:25 CEST 2022
I'm using this server until 2152 at 15:40
Pull Request https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/pull/249 test initiated by fbac
```

