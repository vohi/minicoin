# Provider Notes and Requirements

Vagrant communicates with different virtualization backends using `providers`.
The default provider is [VirtualBox](https://virtualbox.org), since it's free
and ships out of the box with vagrant.

Other providers that minicoin is tested with are:

* [VMware Fusion](https://www.vmware.com/products/fusion.html); use `vmware_desktop`
as the provider
* [Microsoft Azure](https://portal.azure.com); use `azure` as the provider

The provider can be specified explicitly when bringing up a machine:

`$ vagrant up windows10 --provider azure`

or in the declaration of the machine in the `minicoin.yml` file:

```
- name: windows10
  provider: azure
```

Or you can set the `VAGRANT_DEFAULT_PROVIDER` to change the default provider
for all of minicoin runs. If you don't have VirtualBox installed, you should
set the default provider to what you want to use instead.

Other providers that vagrant supports might work with just a few adjustments -
[contributions](contributing.md) welcome!

## VirtualBox

VirtualBox is the default choice for vagrant; it's free and cross platform,
and good enough for most use cases.

When using VirtualBox, you will also need the
[Oracle VM VirtualBox Extension Pack](https://www.virtualbox.org/wiki/Downloads).

Since it's the default, it's the easiest provider to get started, and it's
also the one that minicoin is most actively tested with.

The main disadvantage with VirtualBox is that spinning up machines is slow and
requires a lot of disk space, since the entire basebox image is copied. VirtualBox
doesn't support nested virtualization, hardware acceleration is not great, and
there are no guest additions for macOS virtual machines (so clipboard sharing
doesn't work).


### VirtualBox specific provisioning

Use the `virtualbox` role to provide a list of keys and values that
should be passed on to the specified command of the `VBoxManage` tool.

```
- name: linux
  box: generic/ubuntu1804
  roles:
    - role: virtualbox
      modifyvm: # command of VBoxManage - see help for details
        --description: "My test machine"
```

## VMware Fusion

VMware Fusion requires the
["vagrant-vmware-desktop"](https://www.vagrantup.com/docs/providers/vmware) plugin
to be installed.

`$ vagrant plugin install vagrant-vmware-desktop`

To make minicoin use VMware Fusion, specify it explicitly as the provider when
bringing a box up:

`$ minicoin up windows10 --provider vmware_desktop`

Alternatively, specify vmware_desktop as the provider in your box definition:

```
- name: windows10
  box: tqtc/windows10
  provider: vmware_desktop
```

Starting a new machine with VMware Fusion is very fast, is it doesn't require a full copy
of the basebox image. VMware also supports nested virtualization, which allows running
e.g an Android emulator inside a Ubuntu virtual machine. Lastly, macOS is a fully
supported guest OS on VMware Fusion, so clipboard sharing with the host works.

However, there are some of hiccups in both VMware Fusion and the vagrant plugin. You
might experience frequent issues with the network configuration and port forwarding when
frequently creating and destroying machines. Often, re-running the minicoin command works,
but sometimes it's necessary to restart the `vagrant-vmware-utility` services (using
launchctl or systemctl), to wipe out configuration files (in `/opt/vagrant-vmware-desktop`),
or even to reboot the host computer to reset the network services.

### VMware specific provisioning

Use the `vmware_desktop` role to provide a list of keys and values that
should be used as VMX settings.


## Microsoft Azure

Using Azure with minicoin requires the
['vagrant-azure](https://github.com/Azure/vagrant-azure) plugin to be installed.

`$ vagrant plugin install vagrant-azure`

In addition, the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
needs to be installed, and you need to have valid Azure credentials:

`$ az login`

To confirm that everything is working and that you have access, run

`$ az account show`
`$ az account list-locations -output tsv`

With the azure provider, minicoin will disable all folder sharing, as it is usually
not desired to share an entire home directory with a remote server. Instead, use
the `mutagen` role to set up folder syncing.

If the box for a machine is available for azure as well and defines the azure-specific
attributes, then you can work with the box as usual, passing `--provider azure` to
minicoin when bringing the box up, e.g.

`$ minicoin up windows10 --provider azure`

When defining a box specific to be used with Azure, set the `provider` attribute to
`azure`. Install the `azure` dummy box for vagrant via

`$ vagrant box add azure-dummy https://github.com/azure/vagrant-azure/raw/v2.0/dummy.box --provider azure`

and then use `azure-dummy` as the box in your machine definition. Finally, apply azure specific
provisioning to specify the image from which the box should be deployed, e.g

```
  - name: ubuntu-azure
    box: azure-dummy
    provider: azure
    roles:
      - role: azure
        vm_image_urn: canonical:ubuntuserver:18.04-LTS:latest
      - role: mutagen
        paths:
          - ~/qt/dev/qtbase
```

To start such a box, you won't need to pass the `--provider` parameter to `minicoin up`.

### Azure specific provisioning

Use the `azure` role to provide a list of keys and values that should be
used by the provider:

* `location` - the location in which to launch the VM; defaults to `northeurope`
* `vm_name` - the name the VM should have; generated to be unique by default
* `vm_image_urn` - the name of the image on the Azure marketplace that the VM should use
* `resource_group_name` - the name of the Azure resource group; generated to be unique by default

See the [Azure plugin documentation](https://github.com/azure/vagrant-azure) for a complete list
of available settings.

### Other Azure settings

Account information and credentials are read and generated using the Azure CLI,
and you can use environment variables to override specific settings:

* `AZURE_VM_ADMIN_PASSWORD` - the password for the admin user account on the VM
