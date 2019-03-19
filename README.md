This repository contains a definition of a vagrant development and test
environment for multiple platforms, and helper scripts for executing typical
jobs.

All the useful stuff is in the subdirectory `minicoin`.

# Teaser

```
$ cd minicoin
$ ./run_on.sh ubuntu1804 build-qtbase -- my_branch ~/qt5
```

# Basic Usage

The intended use case is to use the managed machines to build and test a local
clone of Qt, and to run test cases (such as from bug reports or during package
testing), on a wide range of platforms.

Basic machine operations are identical to regular [vagrant](vagrantup.com)
workflows for multi-machine environments:

To see which machines are declared and to check their status, run

`$ vagrant status`

To start a machine, run

`$ vagrant up windows10`

This will download the virtual machine image if needed, boot up the machine,
and run provisioning actions.

*Note:* Running just `$ vagrant up` is not possible, as this would
bring up all machines, downloading several dozen GB of base box images, and
possibly killing the host.

To run a job on the machine, use the `run_on` script (requires bash)

`$ ./run_on.sh test ubunu1804 -- arg1 arg2`

This will also start the machine if it's not running yet. To sign into a
machine, use

`$ vagrant ssh machine`

To use the machine interactively, use the VirtualBox UI to attach a GUI.

To destroy the machine after usage (without confirmation prompt), run

`$ vagrant destroy -f machine`

Other typical commands are `vagrant halt` to shut down the machine (restart
with `up`), `vagrant suspend` to freeze the machine (restart with `resume`),
and the `vagrant snapshot` sub-commands to save known good states of machines
(for instance, after provisioning or cloning). For a full list of commands,
see `vagrant help`.

To destroy all (!) machines without prompting

`$ vagrant destroy -f`

*Note:* Any data that live only on the machines will be lost.

vagrant can operate on multiple machines if you provide the machine name as a
ruby-style regular expression, i.e. the following would shut down all Windows
machines:

`$ vagrant halt -f /windows.*/`

Use `vagrant status /regexp/` to see which machines would be impacted by your
expression (the above would also stop a machine named `no-windows-here`).

For advanced operations, see the **Machine definition** sections below.

# Jobs

Jobs are script files that can be executed from the host on one or more machines.

Jobs are defined in the `jobs` folder, and each subfolder represents a job that
can be executed on machines. Jobs can receive command line arguments, access the
host file system via folder sharing, and use the software installed through
provisioning steps.

## Executing Jobs

Jobs are executed using the `run_on.sh` shell script.

`$ ./run_on.sh ubuntu1804 test -- p1 p2 p3`

This starts the `ubuntu1804` machine if it's not already running, uploads the
`jobs/test` subdirectory to the machine, and then runs the `main.sh` script
(if the guest is Linux or Mac; on Windows the `main.cmd` script).
Any parameters after the double dash `--` will be passed on to the `main`
script.

Output from the script will be directed to time-stamped log files in the `.logs`
subdirectory, one for stdout and one for stderr with a `latest` symlink for the
currnet run. Use `tail -f` to see the output while the script is running, e.g

`$ tail -f .logs/test-ubuntu1804-latest.log`
`$ tail -f .logs/test-error-ubuntu1804-latest.log`

Jobs are executed on the guest as the `vagrant` user. If your script requires
root privileges, use `sudo` etc, or consider making your job a provisioning
step.

## Defining jobs

Unless folder sharing is disabled, job scripts can safely make the following
assumptions:

* the minicoin directory is available in `/minicoin` (or `C:\minicoin`), so
scripts can be found there
* the user's home directory (if not disabled) is available in a "host"
subdirectory the platform's location for user directories (ie 
`/home/host` for linux, `/Users/host` for macOS, `C:\Users\host` on Windows)
* an argument passed to the `run_on` script that includes the user's home on
the host will be adjusted to point to the user's home on the guest, e.g

`$ run_on.sh ubuntu test -- ~/qt`

will call the test script with `/home/host/qt` on Linux, with `/Users/host/qt`
on macOS, and with `C:\Users\host\qt` on Windows.

Otherwise, the roles for the machines will define what other
assumptions scripts can make. See the **Provisioning** section below for
details.


## Available jobs

`$ ./run_on.sh machine1 build-qdoc -- dev`

Builds qdoc on the doc-server machine. Clones qt5 from code.qt.io, checks out
the dev branch, and builds qtbase and qttools into `/home/vagrant/qt5-build`.

`$ ./run_on.sh machine1 build-qtbase -- my_feature ~/qt5`

Clones qt5 from code.qt.io, fetches the local qtbase clone from `~/qt5` on
the host, checks out the `my_feature` branch, runs configure, and then make.


# Machines

minicoin is based on [vagrant](vagrantup.com), but tries to provide a clearer
separation of the data defining machines, and the code implementing the logic.

## Machine definition

Machines are defined in the `machines` section of the `boxes.yml` file. The
default `boxes.yml` file is loaded first; a `boxes.yml` file in `~/minicoin`
will be loaded if present, and can add additional boxes, or override settings
from boxes in the default file.

The following parameters are available:

```
# Mandatory settings

  - name: mandatory # The name of the machine; will also be set as the hostname
    box: mandatory # The vagrant box for the machine, usually as org/boxfile

# Provisioning

    roles: # Optional, as per the definitions in the roles subdirectory
      - role1
      - role2
      - role: role3
        key1: value1
        key2: value2

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

There is only one `Vagrantfile` which contains the vagrant configuration
code, takes care of setting appropriate defaults, works around limitations,
and runs the provisioning steps from the machine's definition. You will
probably never have to change this file.

## Vagrant boxes

Base boxes (and disk images; see **Disk provisioning**) will be downloaded
from the URLs listed in the `urls` section of the `boxes.yml` file. Servers
are attempted in sequence.

```
urls:
  disks:
    - server1
    - server2
  <org>:
    - server1
    - server2
```

The servers listed for an `<org>` key will be used to download boxes for that
org, e.g a box `tqtc/windows10` will be downloaded from the servers set for
org `tqtc`.

For disk images, the URLs under the `disks` key will be attempted.

### Private boxes

Boxes might be located at a private location, in which case the
`box` value for the machine needs to be specified as `org/$minicoin_key/box`, and
the environment variable `$minicoin_key` needs to hold the key, e.g.

```
machines:
  - name: proprietary_os
    box: tqtc/$minicoin_key/proprietary
```

`$ minicoin_key=password123 vagrant up proprietary`

# Provisioning

Provisioning is executed when the machine is booted up for the first time via

`$ vagrant up machine`

or when provisioning is explicitly executed using

`$ vagrant provision machine` or `$ vagrant up --provision machine`

At the end of provisioning, the machine should be able to execute the tasks it
is designed for.

## Default provisioning and file sharing

As part of provisioning the file `~/.gitconfig` will
be copied to the guest, into the homefolder of the `vagrant` user. This allows
you to interact with git repostory servers from within the guest in the same way
as from the host machine.

Unless folder-sharing is disabled, the current directory with the Vagrantfile
will be shared with the guest as a folder `/minicoin`; the home directory of
the current user will be shared with the guest as a folder `host` (`/home/host`
on Linux, `C:\Users\host` on Windows, `/Users/host` on Mac guests).

Folder sharing can be disabled for each box by setting the `shared_folders`
attribute to `disabled`; the global `home_share` setting can be set to something
else than `~`, or to `disabled` to only share the minicoin folder.

## Machine-specific provisioning

Additional provisioning steps are defined using the `roles` attribute in the
machine's definition.

```
- name: simple
  box: generic/ubuntu1804
  roles: test # see roles/test

- name: multiple
  box: generic/ubuntu1804
  roles:
    - base
    - build
    - test

- name: parameterized
  box: generic/ubuntu1804
  roles:
    - role: role-name
      param1: foo
      param2: bar
    - docker: name
      image: foo/bar
```

For each role name, a subdirectories needs to exist within the `roles` directory.
minicoin will automatically set up the respective provisioning, depending on the
diectory contents.

## Supported Provisioners

For each role specified, minicoin will set up one or more vagrant provisioners
depending on the contents of the respective `role` directory. Docker containers
can be run using the special role type `docker`.

As far as the provisioning is executed on the guest, it will be run with root
privileges.

### Scripted

For each subdirectory, minicoin will look for a `provision.sh` file for linux/macOS
guests, or for a `provision.cmd` or `provision.ps1` file for Windows guests. Such
a script will be executed on the guest using shell provisioning.

The script will receive the name of the role for which it was run, the name of
the machine, and the user name on the host, as command line arguments.

If the role is parameterized, then the parameters are passed to the provisioning
script as named arguments, ie the script `roles/arguments/provision.sh` will be
called with arguments `--param1 foo --param2 bar` in the example above.

Scripted provisioning is always done for roles that provide a provision script,
even if there is another provisioner type (such as ansible or disk) present for
that role.

### Docker

minicoin can build a Dockerfile, or run a docker image.

To run an image, use the role type `docker`, and specify the image and other
options as parameters:

```
  - name: webserver
    box: generic/ubuntu1804
    roles:
      - docker: name # name of the container
        image: # mandatory; name of the image; will be pulled if needed
        args: # optional; arguments to be passed to `docker run`
        cmd: # optional; command to execute, overrides default CMD of the image
        restart: # optional; defaults to "always", can be "no"
        detach: # optional; defaults to true, can be "false"
```

If minicoin finds a Dockerfile in the `role` directory, then the Dockerfile
will be built. Parameters are passed to the `docker build` run:

```
  - name: db-server
    box: generic/ubuntu1804
    roles:
      - role: builder
        tag: builder/wasm:5.13
```

This will call `docker build --rm --tag builder/wasm:513`.


### Ansible

If minicoin finds a `playbook.yml` file, then the machine will be provisioned
using [ansible](ansible.com).

### Disks

If minicoin finds a file `disk.yml`, then a disk or drive will be inserted or
attached.

```
file: filename # .iso for a DVD, or .vdi for a drive
archive: archive.zip # a compressed file for downloading
```

A `file` attribute can point to an ISO image, which will be inserted as
a DVD into the guest VM. If `file` points to a VDI file, then that file will be
attached as a harddrive. An ISO image can be attached to multiple guests; a VDI
can as well, but each guest will perform write operations to a separate VDI file.

The drive image file will be looked for in the hidden `.diskcache` folder. If
the file does not exist, then the `archive` attribute can point at a zip-file
that can be downloaded from one of the global URLs under the `disks` key.

Disk are inserted or attached during boot time and before any other provisioners
are run. Boxes might need to specify how the disk can be attached by setting
parameters in the provisioner, e.g

```
- name: linux
  box: generic/ubuntu1804
  roles:
    - role: disk
      storagectl: IDE # defaults to SATA
      port: 1 # default to 1 for ISO, 2 for VDI
      mtype: standard # defaults to multiattach for VDI
```

# Host System Requirements

The virtual machine images are built for [VirtualBox](virtualbox.org).
The machines are managed using [vagrant](vagrantup.com), vagrant 2.2.4
is required.

Remote execution is tested with macOS and Windows 10 as host, using the
bash shell.

While vagrant and minicoin try to make the boxes all behave the same from
the host's perspective, there are some guest-system specific requirements.

## Windows

A guest is identified as running Windows when either the name of the machine,
or the name of the box includes the string "windows".

Windows machines support WinRM and ssh, but only WinRM works reliably for
provisioning. To be able to talk WinRM via vagrant, install the ruby gem
on the host:

`$ sudo gem install winrm`

## Mac

A guest is identified as running MacOS when either the name of the machine,
or the name of the box includes the string "mac".

Since VirtualBox doesn't provide guest additions for Mac systems, minicoin is
using sshfs for file sharing between the guest and the host. For this to work,
the host needs to run an OpenSSL server that allows key based authentication.

When bringing a Mac guest up, minicoin will create a dedicated SSH key pair,
and add the public key to the `~/.ssh/authorized_keys` file. After a box has
been destroyed, these keys will be deleted again, and removed from the
`authorized_keys` file.

# Security notice

Vagrant boxes are by default insecure. They use the default, insecure,
ssh keys that anyone can download from github. This is by design; on some
machines, those default keys will be replaced with secure keys during
provisioning, but not on all.

Even with secure keys, the user credentials are still the default, ie
vagrant/vagrant.

In other words, don't expose those boxes to an untrusted network. By
default, they should be as secure as your host machine.

Boxes from the `generic` namespace are created using packer scripts here:

https://github.com/lavabit/robox
