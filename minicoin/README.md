# Basic Usage

The intended use case is to build and test Qt on VMs managed with minicoin,
and to run test cases (such as from bug reports or during package testing),
on a wide range of platforms.

Basic machine operations are identical to regular [Vagrant](https://vagrantup.com)
workflows for multi-machine environments:

To see which machines are declared, run

`$ minicoin list`

To list them together with their status, run

`$ minicoin status`

To check a single machine, run e.g.

`$ minicoin status ubuntu1804`

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

Jobs are script files that can be executed from the CLI on the host on one or
more machines. For a list of available jobs, run

`$ minicoin jobs`

Jobs are defined in the `jobs` folder, and each subfolder represents a job that
can be executed on machines. Jobs can receive command line arguments, access the
host file system via folder sharing, and use the software installed through
provisioning steps.

See [Defining Jobs](jobs/jobs#defining-jobs) for documentation on how to implement jobs.

## Executing Jobs

Jobs are executed using the `minicoin run` command.

`$ minicoin run ubuntu1804 test --  --flag --param1 value1 arg`

This starts the `ubuntu1804` machine if it's not already running, uploads the
`jobs/test` subdirectory to the machine, and then runs the `main.sh` script
(if the guest is Linux or Mac; on Windows the `main.cmd` script).

The host-users's home directory, the current directory, and any parameters
after the double dash `--` will be passed on to the `main` script.

Jobs are executed on the guest as the `vagrant` user. If your script requires
root privileges, use `sudo` etc, or consider making your job a provisioning
step.

## Job documentation

To see the documentation for a given job, run

`$ minicoin job-help job`

The most important jobs are:

`$ minicoin run [machines...] build-qtmodule`

Builds the Qt submodule in the local directory on the listed machines,
using the Qt from the last build of qtbase.

`$ minicoin run [machines...] build-project`

Build the project in the current working directory on the listed machines,
using the Qt that was built last (via the build-qtmodule job).

# Machines

minicoin is based on [Vagrant](https://vagrantup.com), but tries to provide a
clearer separation of the data defining machines, and the code implementing
the logic.

Machines are defined in the `machines` section of the `minicoin.yml` file. The
default `minicoin.yml` file is loaded first; a `minicoin.yml` file in `~/minicoin`
will be loaded if present, and can add additional boxes, or override settings
from boxes in the default file.

## Machine definition

A machine needs to have a unique name, and a box that `vagrant` can launch a
VM from. All other settings are optional.

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

*Note:* There is only one `Vagrantfile` which contains the vagrant configuration
code, takes care of setting appropriate defaults, works around limitations,
and runs the provisioning steps from the machine's definition. You will
probably never have to change this file, unless you want to
[contribute](docs/contributing.md) to minicoin.

## Vagrant boxes

You can use any functional vagrant box with minicoin. For a list of freely
available boxes, see [vagrantcloud.com](https://vagrantcloud.com). These are
primarily different versions of various linux distributions, perhaps with
some software pre-installed to make them suitable for specific tasks. For
minicoin, the boxes from the "generic" and "bento" namespaces are good choices,
and available for a range of [providers](docs/provider-notes.md).

## Private boxes

Boxes might be located at a private location, in which case the
`box` value for the machine needs to be specified as `org/$minicoin_key/box`, and
the environment variable `$minicoin_key` needs to hold the key, e.g.

```
machines:
  - name: proprietary_os
    box: tqtc/$minicoin_key/proprietary
```

`$ minicoin_key=password123 vagrant up proprietary`

Base boxes (and disk images; see **Disk provisioning**) will be downloaded
from the URLs listed in the `urls` section of the `minicoin.yml` file. Servers
are attempted in sequence.

```
urls:
  <org>:
    - server1
    - server2
```

The servers listed for an `<org>` key will be used to download boxes for that
org, e.g a box `tqtc/windows10` will be downloaded from the servers set for
org `tqtc`.

  disks:
    - server1
    - server2

For disk images, the URLs under the `disks` key will be attempted.

## Default provisioning and file sharing

Default rules are defined in the `settings` section of the `minicoin.yml` files.

Unless folder-sharing is disabled, the minicoin directory with the Vagrantfile
will be shared with the guest as a folder `/minicoin`; the home directory of
the current user (or whatever the `home_share` attribute specifies) will be shared
with the guest as a home-folder in the respective home directory, ie (`/home/$USER`
on Linux, `C:\Users\$USER` on Windows, `/Users/$USER` on Mac guests, with `$USER`
being the user name on the host system).

Folder sharing can be disabled for each box by setting the `shared_folders`
attribute to `disabled`; the global `home_share` setting can be set to something
else than `$HOME`, or to `disabled` to only share the minicoin folder.

On cloud-hosted VMs, folder-sharing should be disabled. Use the file syncing
technologies, for instance `mutagen` through the available role, instead. When
doing so, the location of the files on the guest MUST be in the same relative
location to the `vagrant` user's home as it is on the host machine to the user's
home.

# Roles

Roles define what provisioning steps are executed when the machine is booted up
for the first time via

`$ minicoin up machine`

or when provisioning is explicitly run using

`$ minicoin provision machine`

or

`$ minicoin up --provision machine`

At the end of provisioning, the machine should be able to execute the tasks it
is designed for.

To re-apply a provisioning step defined by a specific role that the machine uses,
run

`$ minicoin provision machine --provision-with role:type`

e.g.

`$ minicoin provision ubuntu1804 --provision-with linux-desktop:script`

## Machine-specific provisioning

Which roles a machine should have after provisioning is defined using the `roles`
attribute in the machine's definition.

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
    - role: arguments
      param1: foo
      param2: bar
    - docker: name
      image: foo/bar
```

See [Supported Roles](roles/README.md) for a list of available roles, and how to
use them.
