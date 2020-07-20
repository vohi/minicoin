# Basebox Maintenance

Basebox maintenance is a time-consuming process and benefits from reasonably
good knowledge of OS configurations, of the relevant virtual machine providers,
and of vagrant.

To make the process more reliable, the `basebox` directory contains a special
Vagrant environment, and a bunch of scripts that allow the maintenance of
existing `tqtc` baseboxes.

## Background details

* Vagrant stores installed boxes in ~/.vagrant.d/boxes
* virtual machines generally consist of a very large disk image, and smaller
  files with meta data, often XML files in "ovf" format
* not all VM providers support the same ovf settings, or the same disk image
  formats

The VM providers we mostly work with are VirtualBox and VMware Fusion, and
these steps are all for VirtualBox. See the section at the end for the steps
to convert an existing VirtualBox basebox into a basebox for VMware.

* VirtualBox VMs and their disk images are stored in `~/VirtualBox VMs`
* VMware Fusion stores machines in `~/Virtual Machines.localized`

## Starting fresh

Use the VirtualBox or VMware controls to create a new virtual machine, and
install the desired operating system. See the `vagrant` documentation for
detailed requirements. In general

* create an administrative user "vagrant" with password "vagrant"
* add the user to the sudoer group using `visudo`
* on all platforms, install OpenSSH and add the insecure vagrant key to the
  .authorized_keys file of the vagrant user
* check the windows and mac subfolders for additional scripts to configure
  platform specific services, such as WinRM
* turn off any automatic update services
* remove anything not needed to keep the size of the package small
* defrag, and overwrite empty space on the disk with 0-bits

## Modifying an existing box

This is sometimes needed to install new guest additions for updates VirtualBox
or VMware versions, to install new OS patches, or also to make a new OS version
available by upgrading an existing box.

For ongoing maintenance, use the special `Vagrantfile` to bring up a virtual
machine from an installed box-file - see `vagrant status` for available boxes.

Bring up a machine from an installed box, e.g:

```
$ vagrant up windows10-basebox
```

This will launch a machine `windows10-basebox` in VirtualBox.

Note that the Vagrantfile prevents the replacement of the insecure keys.

Enter the box using either SSH or the virtual display, and make the
modifications.

## Exporting

Before exporting the machine, consider the following steps to decrease
the size of the machine and make it more compressible:

* delete unnecessary files
* run disk defragmentation
* zero out any free space (on Windows, using SDelete)

When finished, shut the machine down:

```
$ vagrant halt windows10-basebox
```

If you are using VirtualBox, then you might now want to compact the disk
image, which however only works for VDI images. Use the following script:

```
$ ./compact_vdi.sh "~/VirtualBox VMs/windows10-basebox/box-disk001.vmdk"
```

You might have to detach the disk first, but otherwise the script
takes care of all the necessary steps, which take a long time and uses
up a lot of disk space. When done, attach the compacted VDI image back
to the VM.

To export the machine, use the packaging scripts, e.g

```
$ ./package-vbox.sh windows10-basebox windows10-0.0.2
```

This will take a while (and consume significant diskspace), but after a while you should
find a new `windows10-0.0.2.box` file.
That box file should not be significantly larger than the previous version, but the
details depend on how much new software was installed.

## Testing the Box

Add the box to vagrant

```
$ vagrant box add --name tqtc/windows10-0.0.2 windows10-0.0.2.box
```

This takes again a while, vagrant is unpacking the box file into it's boxes storage.
In the meantime, add a test box to your `boxes.yml` file, such as:

```
- name: test-windows10-0.0.2
  box: tqtc/windows10-0.0.2
```

and run a test, e.g

```
$ cd minicoin/tests
$ ./runner.sh test-windows10-0.0.2
```

When everything works as expected, destroy the vagrant box, and remove the box
again from vagrant.

```
$ minicoin destroy -f test-windows10-0.0.2
$ vagrant box remove tqtc/windows10-0.0.2
```

## Publishing the Box

Boxes are published to cloud storage, preferably versioned and tagged for the
respective provider. Versioning and tagging is done through a JSON file, such
as the ones in `minicoin/boxes/tqtc`. If you create a new version or provider
package for an existing box, modify the corresponding JSON file by adding the
respective section. For a new (or previously unversioned) box, create a new
JSON file that has the same name as the box, minus the `tqtc` namespace. Add
the JSON file with the `$server` and `$minicoin_key` unmodified to version
control.

Upload the box via

```
$ ./publish_box windows10-0.0.2.box azure $minicoin_key virtualbox
```

Assuming that your credentials are ok, this will upload a JSON file based
on your edits, with `$server` and `$minicoin_key` replaced with the correct
values, and - if this succeeds - upload the box to the storage location for
`virtualbox` files.

## Testing the published box

The final step is now to bring a minicoin machine up with the published
box. Change the definition of your test-box to use the correct box name,
ie.

```
- name: test-windows10-0.0.2
  box: tqtc/$minicoin_key/windows10
```

and launch the box:

```
$ minicoin up test-windows10.2
```

This should

* identify that there is a new version, 0.0.2, available on the server
* download the new box image
* bring up the box and allow you to work with it

## VMware

Turning the basebox from VirtualBox into a VMware box requires a VMware
license. These steps are based on VMware Fusion.

The first step is to export the basebox virtual machine from VirtualBox
into an appliance, using "Open Virtualization Format v1.0" and including
ISO image files. This will generate an `.ova` file that includes the
VMDK version of the disk, which is the only format that VMware can work
with.

Open that `.ova` file using VMware Fusion, and try to boot it. You might
need to make adjustments to the machine settings before it does so.

Once launched, the only change you have to make is to remove the
VirtualBox guest additions, and to install the VMware tools instead
(requires a CD drive). Turning on support for nested virtualization will
allow the machine to run mobile platform emulators.

When done, shut the machine down and package the box, e.g

```
$ ./package-vmware.sh ~/Virtual\ Machines.localized/windows10-basebox
```

This will result in another huge `windows10-basebox.box` file.

For testing and publishing, follow the same steps as with VirtualBox, just
use `vmware_desktop` as the provider, and when running the publishing script.
