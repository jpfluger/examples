> Back to [Table of Contents](https://github.com/jpfluger/examples)

# NSClient++

Let's be very clear. There are components to monitoring. It's not difficult but can be confusing if not clearly communicated from the outset.

1. Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
2. Clients: Any server we want to monitor will be monitored in one of two ways:
   1. The central server uses ping, http or other commands to execute against the targeted device. No modules are installed on the targeted device.
   2. Install a client module on the remote device, which can then communicate with Icinga2
      * On Linux, install Nagios Remote Plugin Executor (NRPE) on the remote Linux device.
      * On Windows, install NSClient++ NPRE service on the remote Windows device.

The example below are instructions to setup [NSClient](http://www.nsclient.org/about/) to communicate with Icinga2 on Windows 8.1. For instructions on configuring [NPRE](http://exchange.nagios.org/directory/Addons/Monitoring-Agents/NRPE--2D-Nagios-Remote-Plugin-Executor/details), see [this Ubuntu 14.04 example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nagios-npre-client.md).

To have this example work fully, a Central Server installation is required. See [here](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/icinga2-server.md) for help on setting up an Icinga2 Central Server.

## Install NSClient++ on Windows 8.1

> Note: For the examples below, this Windows machines was configured with ip address `192.168.1.21` and has a DNS name of `win81-henry.example.com`.

On the Windows machine, open a web browser and navigate to

```
http://www.nsclient.org/download/
```

Download the Windows `.msi` suitable that maches the architecture of the machine (eg 32-bit v 64-bit). The version installed in this example was version 0.4.1.105.

Double-click to install.

I chose `Typical`.

![NSClient Wizard 1](https://github.com/jpfluger/examples/blob/master/windows/nsclient/nsclient-wiz1.png)

Set the ip address of the Icinga2 Central Server. In these example, this server has an ip of `192.168.1.3`. Also choose to enable common plugins and the npre service.

![NSClient Wizard 2](https://github.com/jpfluger/examples/blob/master/windows/nsclient/nsclient-wiz2.png)

Once installed, configuration options can be found in `nsclient.ini` within the root directory of the `NSClient++` install folder. On my system, it was installed at `C:\\Program Files\NSClient++`.

![NSClient Config Options](https://github.com/jpfluger/examples/blob/master/windows/nsclient/nsclient-expl.png)

---

Open the `nsclient.ini` file. Look for the alias section. I copied the portion that was installed on my machine.

```ini
; A list of aliases available. An alias is an internal command that has been "wrapped" (to add arguments). Be careful so you don't create loops (ie check_loop=check_a, check_a=check_loop)
[/settings/external scripts/alias]

; alias_cpu - Alias for alias_cpu. To configure this item add a section called: /settings/external scripts/alias/alias_cpu
alias_cpu = checkCPU warn=80 crit=90 time=5m time=1m time=30s

...more...

; alias_disk - Alias for alias_disk. To configure this item add a section called: /settings/external scripts/alias/alias_disk
alias_disk = CheckDriveSize MinWarn=10% MinCrit=5% CheckAll FilterType=FIXED

...more...

; alias_mem - Alias for alias_mem. To configure this item add a section called: /settings/external scripts/alias/alias_mem
alias_mem = checkMem MaxWarn=80% MaxCrit=90% ShowAll=long type=physical type=virtual type=paged type=page

...more...

; alias_updates - Alias for alias_updates. To configure this item add a section called: /settings/external scripts/alias/alias_updates
alias_updates = check_updates -warning 0 -critical 0

```

Notice we have commands for:

  * alias_cpu
  * alias_disk
  * alias_mem
  * alias_updates

We will now tell Icinga2 to use these aliases to monitor the Windows machine.

## Icinga2 Central Server

Back on the Icinga2 Central Server, open a terminal and install the Nagios NRPE plugin.


```bash
$ sudo apt-get --no-install-recommends install nagios-nrpe-plugin
```

With the NRPE plugin now installed, let's check the status of the host just configured with NSClient++. Remember that this client has an ip set to `192.168.1.21`.

```bash
$ sudo /usr/lib/nagios/plugins/check_nrpe -H 10.10.11.21
I (0,4,1,105 2014-04-28) seem to be doing fine...
```

The `seem to be doing fine...` message is what we want to see.

---

Tell Icinga2 to use the `check_nrpe` command.  Open `commands.conf`.

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

---

Create a config file for the new host.

```bash
$ sudo vim /etc/icinga2/conf.d/hosts/win81-henry.conf
```

The full file looks like this - note the embedded comments, explaining what each section does.

```
// defines the Host as "win81-henry" as residing at ip address "192.168.1.21"
object Host "win81-henry" {
  import "generic-host"

  address = "192.168.1.21"
  check_command = "hostalive"

  vars.lan = "example.com"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "win81-henry" hosts and has it execute the "alias_cpu" alias
object Service "load" {
  import "generic-service"

  host_name = "win81-henry"
  check_command = "check_nrpe"
  vars.remote_nrpe_command = "alias_cpu"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "win81-henry" hosts and has it execute the "alias_disk" alias
object Service "disk" {
  import "generic-service"

  host_name = "win81-henry"
  check_command = "check_nrpe"
  vars.remote_nrpe_command = "alias_disk"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "win81-henry" hosts and has it execute the "alias_mem" alias
object Service "memory" {
  import "generic-service"

  host_name = "win81-henry"
  check_command = "check_nrpe"
  vars.remote_nrpe_command = "alias_mem"
}

// This services uses "check_nrpe" to connect to port 5666 of the targeted "win81-henry" hosts and has it execute the "alias_updates" alias
object Service "udpates" {
  import "generic-service"

  host_name = "win81-henry"
  check_command = "check_nrpe"
  vars.remote_nrpe_command = "alias_updates"
}
```

Check that configuration syntax is correct.

```bash
sudo service icinga2 checkconfig
```

Restart Icinga2.

```bash
sudo service icinga2 restart
```

Go to the Icinga-Web interface and refresh it. The nrpe checks should be `pending` and eventually will be successful or fail.
