## Defining Jobs

Jobs are represented by directories in the minicoin/jobs. User specific
and local jobs can be defined in the corresponding locations, e.g.
~/minicoin/jobs. Each job directory must contain one or several `main`
scripts - a `main.sh` for Unix-like guests (including macOS), and a
`main.cmd` or `main.ps1` file for Windows guests (`cmd` scripts will have
preference).

When running

```
$ minicoin run guest job
```

The entire job directory will be uploaded to the guest, and executed via
ssh or winrm, with the working directory being the home directory (i.e.
on Linux guests, `/home/vagrant`).

Job scripts can make the following assumptions:

* the first argument passed into the script is the directory on the guest
  on which the job should operate it is the guest equivalent of
* the second argument, which is the directory on the host from which
  `minicoin` was run
* the `minicoin/util` directory is available in `/minicoin/util` (or
`C:\minicoin\util`), so utility scripts such as the option parsers can be
found there

The `parse-opts` scripts in minicoin/util set the `JOBDIR` variable to the
first argument, and will print a warning if that directory does not exist.

This means that running minicoin in your home directory will automatically
set the `JOBDIR` variable to host's home directory mapped to the guest file
system:

```
$ cd ~/qt
$ minicoin run ubuntu1804 windows10 macos1013 test
```

will make the test script print "Job works on '/home/user/qt'" on the
Linux box, "Job works on 'C:\Users\user\qt'" on the Windows box, and
"Job works on '/Users/user/qt'" on the macOS box.

Otherwise, the roles for the machines will define what other
assumptions scripts can make. See the [Roles](../README.md#roles)
section for details.

## Pre- and post-run scripts

If a `pre-run.sh` script exists in the job directory, then that script will
be executed on the host immediately before the main script is executed on the
guest. If the pre-run script returns with a non-zero exit code, the run will
be aborted.

If a `post-run.sh` script exists in the job directory, then that script will
be executed on the host immediately after the main script has returned. The
post-run script will be executed also if the main script terminated with a
non-zero exit code.

The first parameter passed into the pre- and post-run scripts is the name of
the machine on which the job will be run. It's possible to execute minicoin
commands on that machine, i.e.

```
#!/bin/bash
minicoin upload file-on-host $1
```

would upload the respective file to the guest.
