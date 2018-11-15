# First, we clone the necessary git repositories locally so that we don't have
# to pass git credentials etc into the virtual machine. The provisioning script
# can then move those from the shared vagrant folder into the machine.

git clone git@git.qt.io:mikhail.svetkin/rtems.git -b qt5
git clone git@git.qt.io:mikhail.svetkin/rtems-source-builder.git -b qt5

