# Provider Notes and Requirements

minicoin is primarily tested with [VirtualBox](https://virtualbox.org), 
[VMware Fusion](https://www.vmware.com/products/fusion.html), and
[Microsoft Azure](https://portal.azure.com).

Other providers that vagrant supports might work with just a few adjustments -
[contributions](contributing.md) welcome!

## VirtualBox

VirtualBox is the default choice for vagrant; it's free and cross platform,
and good enough for most use cases.

With VirtualBox, you will also need the
[Oracle VM VirtualBox Extension Pack](https://www.virtualbox.org/wiki/Downloads).

It's main disadvantage is that spinning up machines is slow and requires a lot of
disk space, since the entire basebox image is copied. VirtualBox doesn't support
nested virtualization, hardware accelaration is not great, and there are no guest
additions for macOS virtual machines (so clipboard sharing doesn't work).

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

Lastly, you can set the `VAGRANT_DEFAULT_PROVIDER` to `vmware_desktop` to change
the default provider for all of minicoin runs.

Starting a new machine with VMware Fusion is very fast, is it doesn't require a full copy
of the basebox image. VMware also supports nested virtualization, which allows running
e.g an Android emulator inside a Ubuntu virtual machine.

Lastly, macOS is a fully supported guest OS on VMware Fusion, so clipboard sharing with
the host works.

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


When defining a box to be used with Azure in your `boxes.yml` file, set the
`provider` attribute to `azure`, and the `shared_folders` attribute to `disabled`.
The `box` should be either an Azure URN, a managed image, or the URL to a VHD.

```
  - name: ubuntu-azure
    box: canonical:ubuntuserver:18.04-LTS:latest
    provider: azure
    shared_folders: disabled
```

To share folders with the Azure VM, use the `mutagen` role.

### Azure specific provisioning

Use the `azure` role to provide a list of keys and values that should be
used by the provider:

* `location` - the location in which to launch the VM; defaults to `northeurope`
* `vm_name` - the name the VM should have; generated to be unique by default
* `resource_group_name` - the name of the Azure resource group; generated to be unique by default
* 

### Other Azure settings

Account information and credentials are read and generated using the Azure CLI,
and you can use environment variables to override specific settings:

* `AZURE_VM_ADMIN_PASSWORD` - the password for the admin user account on the VM
