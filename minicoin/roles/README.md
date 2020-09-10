# Supported Roles

Each subdirectory within the `roles` directory represents a role. minicoin will
automatically set up the respective provisioning, depending on the directory
contents.

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
