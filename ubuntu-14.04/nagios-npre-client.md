> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Nagios NPRE client

Let's be very clear. There are two components to monitoring. 

* Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
* Clients: Any server we want to monitor will have Nagios Remote Plugin Executor (NRPE)

The examples below cover setting up the **Client**. For setting up the **Central Server**, see [this example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/icinga2-server.md).







# Icinga2 monitoring with Nagios NRPE on nginx and postgresql

Let's be very clear. There are two components to monitoring. 

* Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
* Clients: Any server we want to monitor will have Nagios Remote Plugin Executor (NRPE)

I chose icinga 2 because it is visually more appealing than Nagios but also that plugins developed for Nagios do work in Icinga and vice-versa.


add-apt-repository ppa:formorer/icinga
# apt-get update