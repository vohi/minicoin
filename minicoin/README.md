# Basic Usage

The intended use case is to build and test Qt on VMs managed with minicoin,
and to run test cases (such as from bug reports or during package testing),
on a wide range of platforms.

Basic machine operations are identical to regular [Vagrant](https://vagrantup.com)
workflows for multi-machine environments:

To see which machines are declared and to check their status, run

`$ minicoin status`

To start a machine, run

`$ minicoin up ubuntu1804`

This will download the virtual machine image if needed, boot up the machine,
and run provisioning actions.

*Note:* Running just `$ minicoin up` is not possible, as this would
bring up all machines, downloading several dozen GB of base box images, and
possibly killing the host. Also, note that machines might rely on private
boxes.

To run a job on the machine, execute

`$ minicoin run ubuntu1804 [job]`

This will also start the machine if it's not running yet. To sign into a
machine using ssh, use

`$ minicoin ssh ubuntu1804`

To use the machine interactively, use the VirtualBox UI to attach a GUI, or
e.g.

`$ minicoin rdb windows10`

To destroy the machine after usage (without confirmation prompt), run

`$ minicoin destroy -f ubuntu1804`

*Note:* Any data that lives only on the machine will be lost.

Other typical commands are `halt` to shut down the machine (restart
with `up`), `suspend` to freeze the machine (restart with `resume`),
and the `snapshot` sub-commands to save known good states of machines
(for instance, after provisioning or cloning). For a full list of commands,
see `help`.

To destroy all (!) machines without prompting

`$ minicoin destroy -f`

You can operate on multiple machines if you provide the machine name as a
ruby-style regular expression, i.e. the following would shut down all Windows
machines:

`$ minicoin halt -f /windows/`

Use `minicoin status /regexp/` to see which machines would be impacted by your
expression (the above would also stop a machine named `no-windows-here`).

For advanced operations, see the **Machine definition** sections below.

# Jobs

Jobs are script files that can be executed from the host on one or more machines.

Jobs are defined in the `jobs` folder, and each subfolder represents a job that
can be executed on machines. Jobs can receive command line arguments, access the
host file system via folder sharing, and use the software installed through
provisioning steps.

## Executing Jobs

Jobs are executed using the `minicoin run` command.

`$ minicoin run ubuntu1804 test -- p1 p2 p3`

This starts the `ubuntu1804` machine if it's not already running, uploads the
`jobs/test` subdirectory to the machine, and then runs the `main.sh` script
(if the guest is Linux or Mac; on Windows the `main.cmd` script).

The host-users's home directory, the current directory, and any parameters
after the double dash `--` will be passed on to the `main` script.

Jobs are executed on the guest as the `vagrant` user. If your script requires
root privileges, use `sudo` etc, or consider making your job a provisioning
step.

## Defining jobs

Unless folder sharing is disabled, job scripts can safely make the following
assumptions:

* the first argument passed into the script is the home directory of the user
on the host
* the second argument passed into the script is the directory from which
`minicoin` was run
* the minicoin directory is available in `/minicoin` (or `C:\minicoin`), so
utility scripts can be found there
* the user's home directory (if not disabled) is available in a "host"
subdirectory the platform's location for user directories (ie 
`/home/host` for linux, `/Users/host` for macOS, `C:\Users\host` on Windows)

Job scripts should combine the first and second arguments passed in to map
directories on the host machine to directories on the box. The `parse-opts`
scripts in minicoin/util do this automatically, setting a `JOBDIR` variable
accordingly.

This means that running minicoin in your home directory will automatically
set the `JOBDIR` variable to host's home directory mapped to the guest file
system:

```
$ cd ~/qt
$ minicoin run ubuntu1804 windows10 macos1013 test
```

will make the test script print "Job works on '/home/host/qt'" on the
Linux box, "Job works on 'C:\Users\host\qt'" on the Windows box, and
"Job works on '/Users/host/qt'" on the macOS box. See the code in the
`parse-opts` scripts in `minicoin/util` for how to convert the arguments
manually in your own scripts, if you don't want to use `parse-opts`.

Otherwise, the roles for the machines will define what other
assumptions scripts can make. See the **Provisioning** section below for
details.


## Available jobs

`$ minicoin run [machines...] build-qt -- [--modules a,b]`

Configures and build the Qt5 clone in the local directory on the listed
machines. The optional modules parameter defines which modules to build.

`$ minicoin run [machines...] build-qtmodule`

Builds the Qt submodule in the local directory on the listed machines,
using the qmake from the last build of qtbase.

`$ minicoin run [machines...] build-project`

Build the project in the current working directory on the listed machines,
using the Qt that was built last via the build-qt script.

# Machines

minicoin is based on [Vagrant](https://vagrantup.com), but tries to provide a clearer
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
    ports: optional # a list of port mappings; see vagrant's attributes
    memory: optional # amount of MBs of RAM the machine should have
    cpus: optional # number of CPUs the machine should have
    gui: optional # "true" if the VirtualBox gui should be shown
    vram: optional # amount of MBs of video memory the machine should have
    resolution: optional # display resolution, e.g UXGA or WQXGA
    guiscale: optional # scale factor for the GUI
    screens: optional # number of screens

# Expert options for platform specific quirks

    communicator: optional # the communicator vagrant should use
    shared_folders: optional # set to "disabled" to turn folder sharing off
    os: optional # 'windows' or 'mac', overrides auto detection
    provider: optional # specify which provider should always be used to run this box
```

There is only one `Vagrantfile` which contains the vagrant configuration
code, takes care of setting appropriate defaults, works around limitations,
and runs the provisioning steps from the machine's definition. You will
probably never have to change this file, unless you want to contribute to
minicoin.

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

On cloud VMs, folder-sharing should be disabled. Use the `mutagen` role instead.

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

As a special case, the `script` role can be used to execute an inline script
on the guest, ie.

```
- name: hello
  box: generic/ubuntu1804
  roles:
    - role: script
      script: "echo Hello World"
```

#### Host-side scripting

Roles can provide `pre-provision.sh` and `post-provision.sh` script files; those will
be executed on the host before and after the guest is being provisioned, respectively.
This functionality is not available when using minicoin on a Windows host.

In addition, the `hostscript` role allows the definition of inline scripts that
will be run as pre- and post-provisioning steps on the host:

```
- name: verbose
  box: generic/ubuntu1804
  roles:
    - role: hostscript
      preprovision: "wget latest_keys"
      postprovision: "rm latest_keys"
```

### File provisioning

To upload a file to the guest during provisiniong, use the `upload` role,
and specify a list of local files and remote destinations, e.g:

```
- name: box
  box: generic/ubuntu1804
  roles:
    - role: upload
      files:
        ~/.ssh/id_rsa: ~/.ssh/id_rsa
```

The local file needs to exist on the host. On the guest, the necessary
directory structure will be created automatically.

### Mutagen file system sync

Use the [`mutagen`](https://mutagen.io) role to sync local directories to the
guest file system.

```
- name: box
  box: generic/ubuntu1804
  roles:
    - role: mutagen
      paths:
        - ~/qt/dev/qtbase
        - ~/qt/dev/qtbase
```

By default, `mutagen` will be installed on the guest, and will communicate to
the host system via ssh (which requires an SSH server on the host).

For cloud VMs, `mutagen` should be configured to run in reverse mode by setting
the `reverse` attribute to `true`; this requires a `mutagen` installation on the
host system.

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
using [ansible](https://ansible.com).

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

## Provider-specific provisioning

It's possible to specify provider-specific settings. Many of these changes will
only have an effect when the box is created, and cannot be changed during later
provisioning, or when the box is already running.

See [Provider Notes](docs/provider-notes.md) for provider-specific provisioning
roles.
