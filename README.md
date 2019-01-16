This repository contains a definition of a vagrant development and test
environment for multiple platforms, and helper scripts for executing typical
jobs.

All the useful stuff is in the subdirectory `minicoin`.

# Usage

The intended use case is to use the managed machines to build and test a local
clone of Qt, and to run test cases (such as from bug reports or during package
testing), on a wide range of platforms.

Machines are declared in a yaml file, `boxes.yml`. The `Vagrantfile` contains
the vagrant configuration code, takes care of setting appropriate defaults, and
runs the provisioning steps from the machine's definition. To see which machines
are declared, run

`$ vagrant status`

Running machines can be used via ssh, interactively through virtualbox's display
of the machine, or - if your host can run bash scripts - by executing jobs on
it with the `run_on` script.

## Machine Operations

Basic machine operations are identical to regular [vagrant](vagrantup.com)
workflows for multi-machine environments:

* checking status of all machines

`$ vagrant status`

* Starting a machine

`$ vagrant up windows10`

This will download the virtual machine image if needed, boot up the machine,
and run provisioning actions.

*Warning:* Note that running

`$ vagrant up`

without any machine names will bring up all machines, which involves downloading
several dozen GB of base boxes. You probably don't want that.

* Stopping all Windows machine

`$ vagrant halt windows7 windows81 windows10`

* destroying all (!) machines without prompting

`$ vagrant destroy -f`

## Executing Jobs

Jobs are define in the `jobs` folder. Each subfolder represents a job that can
be executed on machines, using the `run_on.sh` shell script.

`$ ./run_on.sh ubuntu1804 test -- p1 p2 p3`

This starts the `ubuntu1804` machine if it's not already running, uploads the
`jobs/test` subdirectory to the machine, and then runs the `main.sh` script
(if the guest is Linux or Mac; on Windows the `main.cmd` or `main.ps1` script).
Any parameters after the double dash `--` will be passed on to the `main`
script.

If the `doc-server` was started by the script, it will afterwards be stopped
again.

* defining jobs

TBD

* available jobs

`$ ./run_on.sh doc-server build-qdoc -- dev`

Builds qdoc on the doc-server machine. Clones qt5 from code.qt.io, checks out
the dev branch, and builds qtbase and qttools into `/home/vagrant/qt5-build`.

`$ ./run_on.sh doc-server build-qdoc -- dev /home/vohi/qt5 feature`

Clones qt5 from code.qt.io, checks out the dev branch, adds the local Qt5 clone
as a remote, checks out the feature branch from that qttools repository, and
build qdoc into qt5-build.


## Machine definition

Machines are defined in the `boxes.yml` file, in the `machines` section of the
file. The following parameters are available:

```
  -name: mandatory # The name of the machine; will also be set as the hostname
   box: mandatory # The vagrant box for the machine
   roles: optional # One or more subdirectories with provisioning files

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

Additional provisioning steps are defined in the subdirectories that the `roles`
attribute points at in the machine's definition.

```
- name: simple
  box: generic/ubuntu1804
  roles: test

- name: multiple
  box: generic/ubuntu1804
  roles:
    - base
    - build
    - test
```

For each subdirectory, vagrant will look for a `provision.sh` file for linux/macOS
guests, or for a `provision.cmd` or `provision.ps1` file for Windows guests, and
execute such a script using shell provisioning.

If Vagrantfile finds a `playbook.yml` file, then the machine will be provisioned
using [ansible](ansible.com) instead.

If the role directory contains a file `disk` with the name of an ISO image, then
the ISO image will be downloaded from any of the registered URLs, and then
inserted as a DVD into the guest VM. This will happen during boot time and
before any other provisioners are run. Roles that specify a `disk` can also
include a `provision(.sh|.cmd|.ps1)` script.

# Host System Requirements

The virtual machine images are built for [VirtualBox](virtualbox.org).
The machines are managed using [vagrant](vagrantup.com), vagrant 2.2 is
required.

Remote execution is tested with macOS as the host.

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
