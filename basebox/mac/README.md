# Setting up a macOS vagrant box

The safest way to install macOS on a VM is to start an existing
basebox, and to upgrade that box using the AppStore. What might
work best is to add another drive to the VM, and install the new
OS version onto that new drive, but then you have to set things
up again from scratch.



* Credentials: vagrant/vagrant
* Turn on for administrators in Preferences/Sharing
    * Remote Login
    * Remote Management (for all users) with VNC password `vagrant`
* Install
    * xcode command line tools: `xcode-select --install`
    * homebrew
    * for Virtual Box (remove again for VMware)
        * OSXFUSE (via brew cast install osxfuse)
        * sshfs (via brew install sshfs)
    * for VMware
        * VMware Tools
* macOS 10.15 - only for VirtualBox
    * echo -e 'minicoin\t/System/Volumes/Data/private/tmp/vagrant-minicoin' | sudo tee -a /etc/synthetic.conf
* macOS 11
    * adjust /Volumes/EFI/startup.nsh to run boot.efi from correct volume


## Reducing VM Size

macOS boxes can be huge, so removing everything that's not needed
after the installation, and making the disk as compressible as
possible, is important. It's also quite cumbersome.

* run "First Aid" in the disk utility
* shut down the VM, and release the disk from it
* add the disk to another macOS VM, start that VM
* run `diskutil secureErase freespace 0 [new volume]`
* shut down VM, release disk
* run `compact_vdi.sh` on the disk file
* re-attach it to the VM
