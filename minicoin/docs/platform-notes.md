# Platform Notes and System Requirements

The machines are managed using [vagrant](https://vagrantup.com); vagrant 2.2.4
or later is required.

Scripts are developed and tested on macOS and Windows 10 as hosts.

While Vagrant and minicoin try to make the boxes all behave the same from
the host's perspective, there are some guest-system specific requirements:

## Windows

A guest is identified as running Windows when either the name of the machine,
or the name of the box includes the string "windows", or when the "os" attribute
is set to "windows".

Windows machines support WinRM and ssh, but only WinRM works reliably for
provisioning. To be able to talk WinRM via Vagrant, install the ruby gem
on the host:

```
$ sudo gem install winrm
$ sudo gem install winrm-elevated # needed only on some Linux distros
```

## Mac

A guest is identified as running macOS when either the name of the machine,
or the name of the box includes the string "mac", or when the "os" attribute
is set to "macos".

Since VirtualBox doesn't provide guest additions for Mac systems, minicoin is
using sshfs for file sharing between the guest and the host. For this to work,
the host needs to run an OpenSSL server that allows key based authentication.

When bringing a Mac guest up, minicoin will create a dedicated SSH key pair,
and add the public key to the `~/.ssh/authorized_keys` file. After a box has
been destroyed, these keys will be deleted again, and removed from the
`authorized_keys` file.

VMware tools are supported for macOS guests, but the setup is not thoroughly
tested.
