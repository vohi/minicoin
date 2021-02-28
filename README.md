minicoin is a tool designed for building and testing Qt on multiple platforms,
using virtual machines that run either locally, or in the cloud.

This repository contains a vagrant environment, the definition of several
standard virtual machine boxes, and scripts for executing typical jobs.

All the useful stuff, including detailed **[`Documentation for using minicoin`](minicoin/README.md)**, is
in the [`minicoin`](minicoin) subdirectory.

To contribute to minicoin see [contribution guidlines](minicoin/docs/contributing.md).
For basebox maintenance documentation, see the [basebox directory](basebox).

# Teaser

```
$ cd ~/qt5/qtbase
$ minicoin run build ubuntu2004
$ cd ~/my_project
$ minicoin run build ubuntu2004
```

This will first build qtbase from the local ~/qt5/qtbase directory on the
ubuntu1804 box, and then build the project in ~/my_project on the same box,
using the qtbase that was built just before.

# Setup

You need to install [Vagrant](https://vagrantup.com), and a virtual machine
provider that vagrant supports, like [VirtualBox](https://virtualbox.org),
or an account with a cloud provider.
See [provider specific details](minicoin/docs/provider-notes.md) for more
information about providers.

Clone this repository, and if on macOS or Linux, run the `setup.sh` script to
install `minicoin` in `/usr/local/bin`:

```
$ cd minicoin
$ ./setup.sh
```

If you are on a Windows host, you will need a bash shell to use minicoin (f.ex
the bash that comes with git), and also create a script in a directory that is in
the `PATH`, and that forwards calls to the `minicoin` script:

```
$ echo "~/minicoin/minicoin/minicoin \"$@\"" > /bin/minicoin
$ chmod +x /bin/minicoin
```

(if `/bin` is in your `PATH`, such as under the `git bash`).

See the [Platform Notes and System Requirements](minicoin/docs/platform-notes.md)
for platform specific details.

## Optional packages for an optimal experience

Minicoin can do most things with only VirtualBox and vagrant being present, but for an optimal
experience, install the following on your host as well:

* [mutagen.io](https://mutagen.io/documentation/introduction/installation)

Mutagen provides very fast synchronization of your local file system to the guest, and is used
by the [mutagen](https://git.qt.io/vohilshe/minicoin/-/tree/master/minicoin/roles#mutagen-file-system-sync)
role. Installing mutagen on the host is the preferred solution - minicoin will establish the
sync-point on the host. A good practice is to add those folders that you work with regularly to
the default configuration in your personal `~/minicoin/minicoin.yml` file.

If not installed on the host, the role will try to install mutagen on the guest, and "call back"
to the host, which requires an SSH server to run on the host, and a somewhat complex exchange of
authorization keys.

Machines hosted on the cloud cannot call back to the host, so using machines on e.g. Azure
requires a local mutagen installation.

* [Ansible](https://docs.ansible.com/ansible/latest/installation_guide)

Ansible is a tool for automating the provisioning of machines in a declarative way, making
it unnecessary to write complex shell scripts. Some of the prebuild
[roles](minicoin/roles/README.md) use Ansible.

# Configuring minicoin

Minicoin is configured through `minicoin.yml` files. The default, global configuration lives in
the minicoin directory, and includes default setting for folder sharing, and setting that apply to
all machines.

User and project specific `minicoin.yml` files can extend and override those settings. User
settings need to live in `~/minicoin/minicoin.yml`, project specific settings need to live in a
`.minicoin/minicoin.yml` file within the directory from which minicoin will be run.

The following example adds the `mutagen` role to all machine for file system syncing, and the
`ccache` role to Ubuntu hosts:

```
--
settings:
  defaults:
    roles:
      - role: upload
        files:
          $HOME/.gitconfig: ~/.gitconfig
      - role: mutagen
        paths:
          - ~/qt/dev
  /ubuntu.*/:
    roles:
      - role: ccache
        cache_dir: $GUEST_HOMES/$USER/.ccache
        max_size: 20.0G
```

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
