This repository contains a definition of a vagrant development and test
environment for multiple platforms, and helper scripts for executing typical
jobs.

# Usage

The intended use case is to use the managed machines to build and test a local
clone of Qt, and to run test cases (such as from bug reports or during package
testing), on a wide range of platforms.

Machines are declared in a yaml file, `boxes.yml`. The `Vagrantfile` contains
the vagrant configuration code, takes care of setting appropriate defaults, and
runs the provisioning steps from the machine's definition.

Using the machine is then possible via `vagrant ssh`, or interactively through
virtualbox's display of the machine.

## Machine Operations

Basic machine operations are identical to regular [vagrant](vagrantup.com)
workflows for multi-machine environments:

* checking status of all machines

`$ vagrant status`

* Starting a machine

`$ vagrant up windows10`

This will download the virtual machine image if needed, boot up the machine,
and run provisioning actions.

* Stopping all Windows machine

`$ vagrant halt windows7 windows81 windows10`

* destroying all (!) machines without prompting

`$ vagrant destroy -f`

## Executing Jobs

Jobs are define in the `jobs` folder. Each subfolder represents a job that can
be executed on machines, using the `run_on.sh` shell script, ie

`./run_on.sh doc-server test`

This starts the `doc-server` machine if it's not already running, uploads the
`jobs/test` subdirectory to the machine, and then runs the `main.sh` script. If
the `doc-server` was started by the script, it will afterwards be stopped again.

* running a job

TBD

## Machine definition

Machines are defined in the `boxes.yml` file, in the `machines` section of the
file. The following parameters are available:

```
  -name: mandatory # The name of the machine; will also be set as the hostname
   box: mandatory # The vagrant box for the machine
   coin: optional # The subdirectory with the provisioning files

# Optional virtual machine configurations

   private_net: optional # IP address, or "disabled"; use dhcp otherwise
   memory: optional # amount of MBs of RAM the machine should have
   cpus: optional # number of CPUs the machine should have
   gui: optional # "true" if the VirtualBox gui should be shown
   vram: optional # amount of MBs of video memory the machine should have

# Expert options for platform specific quirks

   communicator: optional # the communicator vagrant should use
   shared_folders: optional # set to "disabled" to turn folder sharing off
```

## Provisioning

Provisioning is executed when the machine is booted up for the first time via

`$ vagrant up [machine]`

or when provisioning is explicitly executed using

`$ vagrant provision [machine]`

At the end of provisioning, the machine should be able to execute the tasks it
is designed for.

### Default provisioning and file sharing

As part of provisioning the file `~/.gitconfig` and the `~/.ssh` directory will
be copied to the guest, into the homefolder of the `vagrant` user. This allows
you to interact with git repostory servers from within the guest in the same way
as from the host machine.

If the `COIN_ROOT` environment variable is set to point at the `coin`
subdirectory of a local Qt5 clone, then the entire `coin` subdirectory will be
copied into the home folder of the `vagrant` user on the guest as well.

Unless folder-sharing is disabled, the current directory with the Vagrantfile
will be shared with the guest.

### Machine-specific provisioning

Additional provisioning steps are defined in the subdirectory that the `coin`
attribute points at in the machine's definition.
The Vagrantfile will look for a `provision.sh` file for linux/macOS
guests, or for a `provision.cmd` file for Windows guests, and execute such a
script using shell provisioning.

If Vagrantfile finds a `playbook.yml` file, then the machine will be provisioned
using [ansible](ansible.com) instead.


# Host System Requirements

The virtual machine images are built for [VirtualBox](virtualbox.org).
The machines are managed using [vagrant](vagrantup.com). Remote execution is
tested with macOS as the host.

## Windows specifics

Windows machines support WinRM and ssh, but only WinRM works reliably for
provisioning. To be able to talk WinRM via vagrant, install the ruby gem:

`$ sudo gem install winrm`


# Security notice

Vagrant boxes are by default insecure. They use the default, insecure,
ssh keys that anyone can download from github. This is by design; on some
machines, those default keys will be replaced with secure keys during
provisioning, but not on all.

Even with secure keys, the user credentials are still the default, ie
vagrant/vagrant.

In other words, don't put sensitive stuff on those boxes, don't run them
if you don't need them, and don't expose them to an untrusted network.
