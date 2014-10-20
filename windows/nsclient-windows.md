> Back to [Table of Contents](https://github.com/jpfluger/examples)

# NSClient++

Let's be very clear. There are components to monitoring. It's not difficult but can be confusing if not clearly communicated from the outset.

1. Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
2. Clients: Any server we want to monitor will be monitored in one of two ways:
   1. The central server uses ping, http or other commands to execute against the targeted device. No modules are installed on the targeted device.
   2. Install a client module on the remote device, which can then communicate with Icinga2
      * On Linux, install Nagios Remote Plugin Executor (NRPE) on the remote Linux device.
      * On Windows, install NSClient++ on the remote Windows device.

The example below are instructions to setup [NSClient](http://www.nsclient.org/about/) to communicate with Icinga2 on Windows 8.1. For instructions on configuring [NPRE](http://exchange.nagios.org/directory/Addons/Monitoring-Agents/NRPE--2D-Nagios-Remote-Plugin-Executor/details), see [this Ubuntu 14.04 example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nagios-npre-client.md).

To have this example work fully, a Central Server installation is required. See [here](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/icinga2-server.md) for help on setting up an Icinga2 Central Server.

## Install NSClient++ on Windows 8.1



