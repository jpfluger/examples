> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Firewall with UFW

[UFW](http://manpages.ubuntu.com/manpages/trusty/en/man8/ufw.8.html) is an acronym for Uncomplicated Firewall. If UFW is uncomplicated, then what's a complicated firewall? UFW greatly simplifies iptables and ip6tables and is actually a wrapper around them, alleviating the potential missteps of making a mistake. Still not convinced? Then please reference these iptables [examples](http://www.cyberciti.biz/tips/linux-iptables-examples.html). 

By default, UFW is installed on Ubuntu but is disabled. UFW has configuration files that can be edited. These files are located in:

```bash
$ sudo ls /etc/ufw
```

But one notable file not in `/etc/ufw` is in the `/etc/default` folder.

Open it.

```bash
$ sudo vim /etc/default/ufw
```

We are not using IPv6, so are disabling it here.

```vi
# Set to yes to apply rules to support IPv6 (no means only IPv6 on loopback
# accepted). You will need to 'disable' and then 'enable' the firewall for
# the changes to take affect.
IPV6=no
```

When we send commands to UFW and UFW configures iptables on behalf of us, scripts are written to disk and can be found in:

```bash
$ sudo ls /lib/ufw
```

For what we are doing, we need not make changes to the generated iptables scripts. But for individuals interested in iptables, the scripts can be educational so after finishing these UFW examples, feel free to browse at the contents of the `*.rules` files. 

## Enable UFW

The help command.

```bash
$ sudo ufw help
```

Get the status. Append the verbose command for more information.

```bash
$ sudo ufw status
Status: inactive
```

By default on Ubuntu, UFW is disabled. Let's enable UFW.

```bash
$ sudo ufw enable
```

By default all incoming requests are blocked and all outgoing requests are allowed.

View the status.

```bash
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip
```

We can also view the raw iptables.

```bash
$ sudo ufw show raw | less
```

## Single NIC Configuration

For this scenario, both nginx and openssh-server have been installed. 

We expect port 22 and 80 to be active. What other ports are open?

```bash
$ netstat -ntulp | grep LISTEN 
(No info could be read for "-p": geteuid()=1000 but you should be root.)
tcp        0      0 0.0.0.0:111             0.0.0.0:*               LISTEN      -               
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      -               
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -               
tcp        0      0 10.10.11.20:5666        0.0.0.0:*               LISTEN      -               
tcp6       0      0 :::111                  :::*                    LISTEN      -               
tcp6       0      0 :::80                   :::*                    LISTEN      -               
tcp6       0      0 :::22                   :::*                    LISTEN      - 
```

Port 111 is for rcpbind and port 5666 is a Nagios NRPE client. 

We also see IPv6 ports are active for SSH, nginx and rcpbind. We could disable these within the configurations but we won't do that since we've already disallowed IPv6 in UFW.

Allow SSH and http requests.

```bash
$ sudo ufw limit 22/tcp
$ sudo ufw allow 80/tcp
```

> Note: `limit` refers to connection rate limiting to help prevent brute-force login attacks. When `limit` is used, by default the connection is allowed if there are no more than 6 connections within 30 seconds.

View the status as a numbered list.

```bash
$ sudo ufw status numbered
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     LIMIT IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
```

## Deleting rules

Delete by number.

```bash
$ sudo ufw delete 2
```

Add it back.

```bash
$ sudo ufw allow 80/tcp
```

Delete all rules and disable UFW.

```bash
$ sudo ufw reset
```

> Note: If the IPv6 value is set to "no" in `/etc/default/ufw`, resetting UFW causes no changes to this value; IPv6 is still disabled.

## Hardening the Single NIC

If this is a production server, especially facing the public internet, I would tighten the host firewall rules further.

 * Allow outgoing DNS to a DNS server
 * Allow outgoing HTTP via a Proxy to the Ubuntu Servers defined in /etc/apt/sources.list
 * Allow other outgoing protocols (eg Database Server, SMTP)
 * Reject all other outgoing

UFW nor iptables filters by domain name. It is [recommended](http://serverfault.com/questions/567396/ufw-deny-outbound-except-for-apt-get-updates) to point UFW outbound rules to a proxy-server. 

## Dual NIC Configuration (DMZ)

In another scenario, a server has two network interfaces, typical for a DMZ'ed server.

  * eth0: 192.168.1.3 belongs to the 192.168.1.0 subnet, which is the corporate network
  * eth1: 10.1.1.3 belongs to the 10.1.1.0 subnet, which is the DMZ'ed network

The server I'm referencing has its interfaces set like this:

```bash
$ sudo cat /etc/network/interfaces
iface eth0 inet static
        address 192.168.1.3
        netmask 255.255.255.0
        network 192.168.1.0
        gateway 192.168.1.1
        dns-nameservers 192.168.1.1

auto eth1
iface eth1 inet static
        address 10.1.1.3
        netmask 255.255.255.0
        network 10.1.1.0
        gateway 10.1.1.1
        dns-nameservers 4.2.2.2
```

And routes look like this:

```bash
$ sudo route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.1.1.1        0.0.0.0         UG    0      0        0 eth1
192.168.1.0     *               255.255.255.0   U     0      0        0 eth0
10.1.1.0        *               255.255.255.0   U     0      0        0 eth1
```

Reset UFW.

```bash
$ sudo ufw reset
```

Enable UFW.

```bash
$ sudo ufw enable
```

Allow SSH from anyone connecting via eth0 interface and who is in the 192.168.1.0/24 subnet.

```bash
$ sudo ufw limit in on eth0 from 192.168.1.0/24 to any port 22 proto tcp
```

Allow HTTP from anyone connecting on on eth0 or eth1

```bash
$ sudo ufw allow 80/tcp
```

View the status.

```bash
$ sudo ufw status numbered
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp on eth0             LIMIT IN    192.168.1.0/24
[ 2] 80/tcp                     ALLOW IN    Anywhere
```

## Hardening the Dual NICs

For Dual NICS on a DMZ'ed production server, I would tighten the host firewall rules further. This is similar to how a single NIC was configured except the target destination might be on the internal interface or it might be on the public interface.

 * Allow outgoing DNS to a DNS server
 * Allow outgoing HTTP via a Proxy to the Ubuntu Servers defined in /etc/apt/sources.list
 * Allow other outgoing protocols (eg Database Server, SMTP)
 * Reject all other outgoing

UFW nor iptables filters by domain name. As expressed before, it is [recommended](http://serverfault.com/questions/567396/ufw-deny-outbound-except-for-apt-get-updates) to point UFW outbound HTTP rules to a proxy-server. 

## Applications

We aren't going to use the **applications** feature right now but it might be something to take advantage of in the future. 

List the applications that UFW knows have been installed.

```bash
$ sudo ufw app list
```

The app list is generated by entries found in:

```bash
$ sudo ls /etc/ufw/applications.d/
```

Open one of the files listed in there to see how to create a new application.