> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Nagios NPRE client

Let's be very clear. There are two components to monitoring. 

* Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
* Clients: Any server we want to monitor will be monitored in one of two ways:
  1. The central server uses ping, http or other commands to execute against the targeted device. No modules are installed on the targeted device.
  2. Install Nagios Remote Plugin Executor (NRPE) installed on the target server. NRPE will communicate with Icinga2.

The examples below cover setting up the **Client**. For setting up the **Central Server** or targeting devices from the Central Server, see [this example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/icinga2-server.md).  To have this example work fully, a Central Server installation is required.

This example will install NPRE on a Linux Ubuntu 14.04 server and Windows 8.1:

* [Install NPRE on Ubuntu Linux 14.04](#install-npre-on-ubuntu-linux-14.04)
* [Install NPRE on Windows 8.1](#install-npre-on-windows-8.1)

## Install NPRE on Ubuntu Linux 14.04

I modifed this [Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-use-icinga-to-monitor-your-servers-and-services-on-ubuntu-14-04) tutorial for these examples.




## Install NPRE on Windows Server 2008



## Install NPRE on Windows 8.1

