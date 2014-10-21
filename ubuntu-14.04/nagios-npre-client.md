> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Nagios NPRE client

Let's be very clear. There are components to monitoring. It's not difficult but can be confusing if not clearly communicated from the outset.

1. Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
2. Clients: Any server we want to monitor will be monitored in one of two ways:
   1. The central server uses ping, http or other commands to execute against the targeted device. No modules are installed on the targeted device.
   2. Install a client module on the remote device, which can then communicate with Icinga2
      * On Linux, install Nagios Remote Plugin Executor (NRPE) on the remote Linux device.
      * On Windows, install NSClient++ NPRE service on the remote Windows device.

The example below covers setting up [NPRE](http://exchange.nagios.org/directory/Addons/Monitoring-Agents/NRPE--2D-Nagios-Remote-Plugin-Executor/details) on Ubuntu 14.04. For help on installing [NSClient++](http://www.nsclient.org/about/) on Windows see [this Windows 8.1 example](https://github.com/jpfluger/examples/blob/master/windows/nsclient-windows.md).

To have this example work fully, a Central Server installation is required. See [here](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/icinga2-server.md) for help on setting up an Icinga2 Central Server.

## Install NPRE on Ubuntu Linux 14.04

On an Ubuntu 14.04 installation, I configured the ip to be `192.168.1.20` and the hostname to be `ub14-henry`.

Install the NPRE packages.

```bash
$ sudo apt-get install nagios-plugins nagios-nrpe-server
```

Get the name of root filesystem because we will enter that in the npre config file next. My filesystem is `/dev/vda1`.

```bash
$ df -h /

#OUTPUT
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        18G  4.4G   13G  27% /
```

Open the npre config file.

```bash
$ sudo vim /etc/nagios/nrpe.cfg
```

Edit as follows: 

```
# Change the server address to the private local ip of the server. 
server_address=192.168.1.20

# Tell this npre that it is okay for the ip address of the Icinga2 Central Server to connect to it
allowed_hosts=192.168.1.3

# Change /dev/hda1 to my root filesystem name, /dev/vda1
command[check_hda1]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /dev/vda1
```

Restart npre.

```bash
$ sudo service nagios-nrpe-server restart
```

---

In the `nrpe.cfg` file, notice commands that were commented in, such as:

```
command[check_users]=/usr/lib/nagios/plugins/check_users -w 5 -c 10
command[check_load]=/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20
command[check_hda1]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /dev/vda1
command[check_zombie_procs]=/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z
command[check_total_procs]=/usr/lib/nagios/plugins/check_procs -w 150 -c 200 
```

`check_users`, `check_load`, `check_hda1`, `check_zombie_procs` and `check_total_procs` are the names of command that can be associated with `check_nrpe` when we configure that Icinga2 Central Server service.

But on the client, test if this command works.

```bash
$ sudo /usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /dev/vda1
DISK OK - free space: / 12628 MB (73% inode=81%);| /=4448MB;14410;16211;0;18013
avatar@ub14-henry:~$ sudo vim /etc/nagios/nrpe.cfg
```

## Icinga2 Central Server

Back on the Icinga2 Central Server, we need to install the Nagios `check_nrpe` plugin. Using `--no-install-recommends` installs the plugin only and not the extra nagios3-related libraries.

```bash
$ sudo apt-get --no-install-recommends install nagios-nrpe-plugin
```

Open `commands.conf`.

```bash
$ sudo vim /etc/icinga2/conf.d/commands.conf 
```

Add a new `CheckCommand`, giving it the name `check_nrpe`.

```
object CheckCommand "check_nrpe" {
  import "plugin-check-command"

  command = [
    PluginDir + "/check_nrpe",
    "-H", "$address$",
    "-c", "$remote_nrpe_command$",
  ]
}
```

Create a config file for the new host.

```bash
$ sudo vim /etc/icinga2/conf.d/hosts/ub41-henry.conf
```

The full file looks like this - note the embedded comments, explaining what each section does.

```
// defines the Host as "ub14-henry" as residing at ip address "192.168.1.20"
object Host "ub14-henry" {
  import "generic-host"

  address = "192.168.1.20"
  check_command = "hostalive"

  vars.lan = "example.com"
}

// The ping4 command is initiated by the Icinga2 Central Server and pings the targeted host, ub14-henry
object Service "ping4" {
  import "generic-service"

  host_name = "ub14-henry"
  check_command = "ping4"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "ub14-henry" hosts and has it execute the "check_users" command
object Service "users" {
  import "generic-service"

  host_name = "ub14-henry"

  check_command = "check_nrpe"
  vars.remote_nrpe_command = "check_users"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "ub14-henry" hosts and has it execute the "check_load" command
object Service "load" {
  import "generic-service"

  host_name = "ub14-henry"
  check_command = "check_nrpe"
  vars.remote_nrpe_command = "check_load"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "ub14-henry" hosts and has it execute the "check_hda1" command
object Service "disk" {
  import "generic-service"

  host_name = "ub14-henry"
  check_command = "check_nrpe"
  vars.remote_nrpe_command = "check_hda1"
}
```
