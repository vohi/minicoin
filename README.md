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
$ minicoin run ubuntu1804 build-qtmodule
$ cd ~/my_project
$ minicoin run ubuntu1804 build-project
```

This will first build qtbase from the local ~/qt5/qtbase directory on the
ubuntu1804 box, and then build the project in ~/my_project on the same box,
using the qtbase that was just built before.

# Setup

You need to install [Vagrant](https://vagrantup.com), and a virtual machine
provider that vagrant supports, like [VirtualBox](https://virtualbox.org),
or an account with a cloud provider.
See [provider specific details](minicoin/docs/provider-notes.md) for more
information.

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
