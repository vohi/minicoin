This repository contains a declaration of a vagrant development and test
environment for multiple platforms, and helper scripts for executing typical
jobs.

The intended use case is to use the managed machines to build an test a local
clone of Qt, and to run test cases (such as from bug reports or during package
testing) on a wide range of platforms.

Machines are declared in a yaml file, `boxes.yml`. The `Vagrantfile` contains
the vagrant configuration code and takes care of setting appropriate defaults.

## Usage

Basic workflow:

* Starting a machine

`vagrant up windows10`

This will download the virtual machine image if needed, and run provisioning
actions.

* running a build job

TBD

* Stopping Windows machine

`vagrant halt windows7 windows81 windows10`

* destroying all machines

`vagrant destroy -f`


## Requirements

The virtual machine images are built for [VirtualBox](virtualbox.org).
The machines are managed using (vagrantup.com)[vagrant].

### Windows specifics

Windows machines support WinRM and ssh, but only WinRM works reliably for
provisioning. To be able to talk WinRM via vagrant, install the ruby gem:

`$ sudo gem install winrm`


## Security notice

Vagrant boxes are by default insecure. They use the default, insecure,
ssh keys that anyone can download from github. This is by design; on some
machines, those default keys will be replaced with secure keys during
provisioning, but not on all.

Even with secure keys, the user credentials are still the default, ie
vagrant/vagrant.

In other words, don't put sensitive stuff on those boxes, don't run them
if you don't need them, and don't expose them to an untrusted network.
