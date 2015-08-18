multicore
=========

This package provides an interface to execute jobs on multiple matlab processes. This is a modified version of the excellent package by Markus Buehren, originally published MATLAB Central with a BSD License.

The code has been revised mainly to simplify the exception handling, slave process management, and the configuration. Here is a short summary of some such changes:
* Ctrl-C in a slave process now allows another slave (or the master) to restart running on the job.
* Ctrl-C in a master process will delete all corresponding parameter/etc. files.
* Slaves now clear matlab's function cache automatically.
* Caller's working directory is now handled properly within slave processes, which avoids common relative path and matlab path related issues.
* In case of an exception/error during execution in a worker, all (remaining) parameter files are deleted, and the corresponding exception info is transferred to the master process. It is now not necessary to restart slaves in case of an exception.
* Multiple master processes can now utilize the share slave process pool, and run simultaneously. Slave processes can now act as master processes, ie. can create new jobs in a recursive manner.
* Default directory is now set via the multicoredirs() function. (It is a good idea to call this function in startup.m)
* Multiple multicoreDir entries is now supported.
* File ids are revised to avoid name clashes.
* disablemc option in startmulticoremaster can now be used to easily enable/disable multicore package. If
  disablemc=true, startmulticoremaster executes the jobs using a simple for-loop.
* Many other minor improvements in the code and API.

USAGE 

* Add multicoredirs() calls to startup.m before running any matlab instances.
  Example: multicoredirs('global',fullfile(getenv('HOME'),'multicore'));  
  In order to use multiple machines via multicore package, this folder needs to be on a network drive.
* Initialize slave processes on several matlab instances via startmulticoreslave(). Slaves on multiple machines can be used by hosting the source code on a network drive.
* Execute jobs via startmulticoremaster().

See multicore_example() for an example.


