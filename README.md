# Root Run Systemd Service

## What does it do?

Rootrun provides a solution to allow users without root access or sudo permissions to execute scripts as root with suitable auditing of the changes that have been made.

## Installation

* Run the install script
```bash
curl https://raw.githubusercontent.com/alces-software/rootrun/master/install.sh |/bin/bash
```

The installation script will install the rootrun program under `/opt/rootrun/` and the service to systemd.

## Adding Scripts

Simply copy any scripts to be run on the client to a sub-directory of the script directory which can be changed in `/opt/rootrun/rootrun.yaml` and it will be executed within the `interval` setting. 

- `/*scriptdir*/*hostname*` - These scripts will only be executed for clients with the specified short hostname
- `/*scriptdir*/all` - These scripts are executed on any client
- `/*scriptdir*/*group*` - These scripts run on clients with *group* in `/opt/rootrun/rootrun.yaml`
