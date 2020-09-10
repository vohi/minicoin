## Defining Jobs

Unless folder sharing is disabled, job scripts can safely make the following
assumptions:

* the first argument passed into the script is the home directory of the user
on the host
* the second argument passed into the script is the directory from which
`minicoin` was run
* the `minicoin/util` directory is available in `/minicoin/util` (or
`C:\minicoin\util`), so utility scripts can be found there
* the user's home directory (if not disabled) is available in a "host"
subdirectory the platform's location for user directories (ie 
`/home/host` for linux, `/Users/host` for macOS, `C:\Users\host` on Windows)

Job scripts should combine the first and second arguments passed in to map
directories on the host machine to directories on the box. The `parse-opts`
scripts in minicoin/util do this automatically, setting a `JOBDIR` variable
accordingly.

This means that running minicoin in your home directory will automatically
set the `JOBDIR` variable to host's home directory mapped to the guest file
system:

```
$ cd ~/qt
$ minicoin run ubuntu1804 windows10 macos1013 test
```

will make the test script print "Job works on '/home/host/qt'" on the
Linux box, "Job works on 'C:\Users\host\qt'" on the Windows box, and
"Job works on '/Users/host/qt'" on the macOS box. See the code in the
`parse-opts` scripts in `minicoin/util` for how to convert the arguments
manually in your own scripts, if you don't want to use `parse-opts`.

Otherwise, the roles for the machines will define what other
assumptions scripts can make. See the [Roles](../README.md#roles)
section for details.