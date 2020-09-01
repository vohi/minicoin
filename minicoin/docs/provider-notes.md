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

## VMware Fusion

VMware Fusion requires the
["vagrant-vmware-desktop"](https://www.vagrantup.com/docs/providers/vmware) plugin
to be installed.

`$ vagrant plugin install vagrant-vmware-desktop`

Starting a new machine wiht VMware Fusion is very fast, and VMware also supports
nested virtualization, which allows running e.g an Android emulator inside a Ubuntu
virtual machine.

macOS is a fully supported guest OS on VMware Fusion.

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
