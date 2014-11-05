> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Ubuntu networking

These examples describe in detail different situations on how to configure networking on Ubuntu Server 14.04 with kvm-libvirt, Openvswitch, bridge-utils, bonding and vlans. I will try to shed light on what can be maddingly [confusing](https://bugs.launchpad.net/serverguide/+bug/1103870) subject matter, especially given that web-examples tend to only cover one-aspect of an implementation. This creates a situation when one reads through a 2nd tutorial, then a 3rd, 4th and 5th and they are all different but yet all correct configurations!  

The goal is to take the mystery out of Ubuntu networking by examples. This will help you understand Ubuntu's current networking options so that you can better marry that to your own project's networking requirements.

We will cover:

* Can the hardware run kvm?
* Identify hardware network interfaces
* Install additional packages
* Unraveling mysteries
* Summary of interface choice configurations
* eth0 (dhcp and static)
* eth0:0 (multiple IPs using aliases on a single network interface)
* eth1 (a second network interface)
* br0 (bridge) where bridge_ports = eth1
* br1 (bridge) where bridge_ports = none
* Adding Uncomplicated Firewall (ufw)
* Create VM hosts within the Test Server

## My test system

You do not need to configure a test system in order to follow along the examples below. But I describe my test environment so that results might be replicated, if so desired.

If you want to follow the examples, you may run the commands on (1) a clean install of Ubuntu Server 14.04 or (2) within a VM of Ubuntu Server. I chose the second option, although the first would work, so long as the test Server is pingable within its own network to verify network connectivity.

My laptop is the hypervisor using kvm-libvirt and a bridge. In a new VM, I installed Ubuntu Server 14.04. I also added a second network interface card to the VM.  During installation the setup wizard asks which networking interface should be primary. I chose `eth0` and left `eth1` unconfigured.  The install automatically assigned eth0 to use DHCP. This VM is the **Server** that all my tests will run against. In my examples below, I will configure this VM for networking and will turn it into a hypervisor. From within this Server, we will create a child VM. My laptop acts as the public internet. All three working together allow me to validate network connections and firewall rules.

Let me define the roles of the devices in my test system. I include synonyms for how the devices may be referenced in my examples.

* Laptop: root system hypervisor, acts as external client for ping tests, it's my test system version of the public internet
* VM Server: the "Server", the "Test Server", test VM hypervisor, most networking configurations done here, will create a child VM to use for testing with it. 
* Child VM: the "Host", the "Child Host", used to validate network connectivity and firewall rules

All commands issued within these examples either run on the VM Server or its child host instances. When I say ping the Server externally, I will be pinging the VM Server from the laptop because my laptop is in effect outside the visibility of the VM Server's sub-networks.

> Note: Typically I would have one single hypervisor at the Laptop level and not two. It is only to assist in my testing that I created the VM Server acting as a hypervisor.

## Post-install tasks

Ok, with a clean install of Ubuntu Server 14.04 just finished, ensure the system is up-to-date and an ssh server has been installed.

```bash
$ sudo apt-get dist-upgrade
$ sudo apt-get install openssh-server
```

Get the IP address of the running system.

```bash
$ ifconfig eth0 | grep inet
inet addr:10.10.11.248  Bcast:10.10.11.255  Mask:255.255.255.0
```

The server's currently configured IP is 10.10.11.248, which was allocated by DHCP.

From an external device, ping this Server.

```bash
$ $ ping -c 3 10.10.11.248
PING 10.10.11.248 (10.10.11.248) 56(84) bytes of data.
64 bytes from 10.10.11.248: icmp_seq=1 ttl=64 time=0.222 ms
64 bytes from 10.10.11.248: icmp_seq=2 ttl=64 time=0.326 ms
64 bytes from 10.10.11.248: icmp_seq=3 ttl=64 time=0.517 ms

--- 10.10.11.248 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2000ms
rtt min/avg/max/mdev = 0.222/0.355/0.517/0.122 ms
```

Good, now we are ready to get started. You may also now use `ssh` to connect to the Server.

```bash
$ ssh USER@10.10.11.248
```

But beware that during the course of these examples the ssh IP address will change and we will loose connectivity. When the IP address changes, external clients may complain of possible compromises to the ssh certificate. On the external client, run the following to remove the fingerprint from `known_hosts` and allow reassignment of the certificate using the new IP address.

```bash
$ ssh-keygen -R 10.10.11.248
$ ssh USER@NEW-IP-ADDRESS
```

## Can the hardware run kvm?

Answer this question: "Can this hardware or VM instance run kvm?" The answer can be found in Ubuntu's [pre-installation checklist](https://help.ubuntu.com/community/KVM/Installation).

Run this command.

```bash
$ sudo egrep -c '(vmx|svm)' /proc/cpuinfo
4
```

If the command returns 1 or more, then the CPU supports hardware virtualization and make sure it's enabled in the BIOS.

Install cpu-checker.

```bash
$ sudo apt-get install cpu-checker
```

Run kvm-ok.

```bash
$ kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used
```

## Identify hardware network interfaces

For most devices, network connectivity begins by enabling WIFI or plugging in a physical connecter (eg RJ-45 jack) to a network card.

Ubuntu uses [udev](http://manpages.ubuntu.com/manpages/trusty/man7/udev.7.html) to know manage software device events, such as mapping physical hardware to software.

Get a list of physical hardware attached to this Test Server.

```bash
$ lspci

# OR filter by term (e.g. "ethernet" or "wireless")... case insensitive search
$ lspci | grep -i ethernet
$ lspci | grep -i wireless
```

In the list you will see a hardware address followed by a description. Here are my lspci values for the two network card interfaces associated with the Test Server:

```
00:03.0 Ethernet controller: Red Hat, Inc Virtio network device
00:04.0 Ethernet controller: Red Hat, Inc Virtio network device
```

Now in the udev logs, we can search for devices mapped to interfaces by the pci number associated with the device.

```bash
$ grep -i \(net\) /var/log/udev | sort -u
KERNEL[0.800126] add      /devices/pci0000:00/0000:00:03.0/virtio0/net/eth0 (net)
KERNEL[0.800138] add      /devices/pci0000:00/0000:00:04.0/virtio1/net/eth1 (net)
KERNEL[0.800863] add      /devices/virtual/net/lo (net)
UDEV  [0.851846] add      /devices/pci0000:00/0000:00:03.0/virtio0/net/eth0 (net)
UDEV  [0.869047] add      /devices/pci0000:00/0000:00:04.0/virtio1/net/eth1 (net)
UDEV  [0.905996] add      /devices/virtual/net/lo (net)
```

These results show we have interfaces for `lo`, `eth0` and `eth1`. Notice the pci device points grep'ed from lspci are within the device path. 

> Note: If anyone knows a better one-liner command that gives me physical-to-interface results, please let me know!

To explore network hardware details, please see the examples on [linuxnix.com](http://www.linuxnix.com/2013/06/find-network-cardwiredwireless-details-in-linuxunix.html). Some of these tools only report back desired results on the root device and not within a Virtual Machine instance.

## Install additional packages

Before we install any packages, let's run a sanity check and see what interfaces are **expected** to run on our current Test Server. 

```bash
$ cat /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
```

We are expecting `lo` and `eth0` to be running. Are they?

```bash
$ sudo ifconfig
eth0      Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.248  Bcast:10.10.11.255  Mask:255.255.255.0
          inet6 addr: fe80::5054:ff:fe87:a522/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1011 errors:0 dropped:0 overruns:0 frame:0
          TX packets:717 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:116505 (116.5 KB)  TX bytes:119967 (119.9 KB)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

Yes, they are present and the link is in an "UP" state.

---

Install these Openvswitch packages.

```bash
$ sudo apt-get install openvswitch-switch openvswitch-common
```

Install the following packages for kvm.

```bash
$ sudo apt-get install qemu-kvm libvirt-bin bridge-utils ubuntu-vm-builder qemu-system
```

> Note: I included qemu-system, which provides emulation binaries for other architectures. If you develop for embedded systems, you will need this installed.

Add to user groups.

```bash
$ sudo adduser `id -un` libvirtd
$ sudo adduser `id -un` kvm
```

Reboot.

```bash
$ sudo reboot now
```

Log back in.

## Unraveling mysteries

Remember the sanity check we ran before?  Let's see which networking interfaces are available **now**.

```bash
$ ifconfig

# My Results: Truncated
eth0      Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.248  Bcast:10.10.11.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0

virbr0    Link encap:Ethernet  HWaddr b2:ed:68:06:7c:ec  
          inet addr:192.168.122.1  Bcast:192.168.122.255  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
```

As seen, the `virbr0` interface has been added.  Where has this interface been defined? Is it in the `interfaces` file?

```bash
$ cat /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
```

No, `virbr0` has not been defined there. What is going on?

We need to use a couple of other commands to view the system modifications that happened.

Have any bridges been configured?

```bash
$ brctl show
bridge name	bridge id		STP enabled	interfaces
virbr0		8000.000000000000	yes	
```

Yes, one bridge entry. Okay, so we know that this `virbr0` interface is tied to a bridge named `virbr0`. 

Has the routing table been modified?

```bash
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.10.11.1      0.0.0.0         UG    0      0        0 eth0
10.10.11.0      *               255.255.255.0   U     0      0        0 eth0
192.168.122.0   *               255.255.255.0   U     0      0        0 virbr0
```

Yes, a virbr0 entry has been added to the routing table, as well.

I'll repeat: what's going on here?

Let me take a step back in time. Before libvirt was installed, `virbr0` did not exist. We only had interfaces for loopback and eth0.  `virbr0` means "virtual bridge 0" and was automatically created by libvirt during installation. `virbr0` was configured as a NAT-only interface. This means virtual machine hosts that use this bridge can get out to the network via the `eth0` interface but any devices on the other side cannot initiate requests into virbr0 clients.

I would suggest reading through this libvirt wiki on [Virtual Networking](http://wiki.libvirt.org/page/VirtualNetworking).

If you are a newbie, that [Virtual Networking](http://wiki.libvirt.org/page/VirtualNetworking) read was probably pretty heavy stuff. If you aren't a newbie, you might be even more confused than you are now. Why does libvirt create a `virtual bridge` when it could be using the standard linux `brctl` to create and edit bridges?  The libvirt virtual bridge allows libvirt to offer more features and interactivity than the standard Linux networking and `brctl` command. It adds NAT, DNSMASQ and iptables rules for us, alleviating work for creating certain configurations. It even creates a DHCP pool for connected VM hosts within the virbr0 subnet.

Because libvirt adds extra networking features, it creates virtual bridge files in `/etc/libvirt/qemu/networks/`.

```bash
$ sudo ls -l /etc/libvirt/qemu/networks/
total 8
drwxr-xr-x 2 root root 4096 Nov  1 12:15 autostart
-rw-r--r-- 1 root root  228 Oct  6 21:13 default.xml
```

But do not edit or create a new file with your favorite text editor. libvirt gives us a tool to manage its virtual networks. After using this tool to open a file and edit, its post-save script will apply the new configurations, applying them to the appropriate tools (eg DHCP Server, iptables).

View available networks.

```bash
$ virsh net-list --all
 Name                 State      Autostart     Persistent
----------------------------------------------------------
 default              active     yes           yes
``` 

Edit a network file.

```bash
$ virsh net-edit default
```

My configuration shows:

```xml
<network>
  <name>default</name>
  <uuid>80b3425e-848b-4187-baf9-dd915e1d84c1</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
```

Ah-ha!  Did you realize virbr0 actually has an IP address assigned to it?

Try pinging `192.168.122.1` from an external client.

```bash
$ ping -c 3 192.168.122.1
PING 192.168.122.1 (192.168.122.1) 56(84) bytes of data.

--- 192.168.122.1 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2015ms
```

The ping request fails because the external router does not have knowledge of this network. Because my external network is emulated by my Linux Laptop, I can add the 192.168.122.0/22 network to my Laptop routing table and the ping works.

```
$ sudo route add -net 192.168.122.0 netmask 255.255.255.0 br0
$ ping -c 3 192.168.122.1
PING 192.168.122.1 (192.168.122.1) 56(84) bytes of data.
64 bytes from 192.168.122.1: icmp_seq=1 ttl=64 time=0.339 ms
64 bytes from 192.168.122.1: icmp_seq=2 ttl=64 time=0.160 ms
64 bytes from 192.168.122.1: icmp_seq=3 ttl=64 time=0.181 ms

--- 192.168.122.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.160/0.226/0.339/0.081 ms
```

---

To this point, we've seen the changes libvirt makes to the system during the default install.

But what about Openvswitch?  Did it make any changes?

```bash
$ sudo ovs-vsctl show
261a513a-ccdb-447d-a31b-5c6296eb102b
    ovs_version: "2.0.2"
```

No networking changes occurred during the Openvswitch installation. (Whew!)  We will configure Openvswitch later!

## Summary of interface choice configurations

What are my interfaces choices and how do I understand how to interact with them?

One fact to accept is that multiple interfaces can be assigned to use a single device definition (eg eth0) and that the single device definition knows how to manage data for that assigned interface. For example, five rows below (eth0, eth0:1, eth0:2, br1 and virbr1) map to device definition eth0.

| Interface      | Subsystem Responsible  | Maps to Device Definition (Default)               | By default, can an external device ping the IP assigned to the Interface?                                |
|:---------------|:-----------------------|:--------------------------------------------------|:---------------------------------------------------------------------------------------------------------|
| eth0           | linux                  | eth0                                              | yes                                                                                                      |
| eth0:1         | linux                  | eth0                                              | yes b/c this is an [alias interface](https://wiki.debian.org/NetworkConfiguration#Multiple_IP_addresses_on_One_Interface) |
| eth1           | linux                  | eth1                                              | yes                                                                                                      |
| wlan0          | linux                  | wlan0                                             | yes, if connected through the same WIFI router                                                           |
| br0            | linux; port = **eth1** | eth1                                              | yes b/c it uses eth1, which is a direct physical device definition                                       |
| br1            | linux; port = **none** | no mapping (isolated bridge)                      | yes (why?)                                                                                               |
| virbr0         | libvirt; NAT mode      | eth0 via iptables                                 | yes but not hosts                                                                                        |
| virbr1         | libvirt; route mode    | eth0 via iptables                                 | yes b/c it uses libvirt's virsh net-* commands to create a routable bridge                               |
| ovsbr0 (to-do) | openvswitch            | br0                                               | yes                                                                                                      |
| bond0 (to-do)  | linux                  | eth0, eth1                                        | yes                                                                                                      |

Another fact to accept is that not all interfaces are configured in the traditional location of `/etc/network/interfaces` but rather libvirt's virtual bridges must be edited through `virsh` even though they are saved in `/etc/libvirt/qemu/networks/` and Openvswitch commands use `ovs-vsctl`. 

The remaining examples cover common implementations for each of these Interfaces.

## eth0 (dhcp and static)

Open the linux subsystem networking `interfaces` file.

```bash
$ sudo vim /etc/network/interfaces
```

Remember that during installation, eth0 was told to use DHCP.

```
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
```

> Note: The loopback interface (`lo`) will never be changed in any of the following examples.

Let's replace DHCP with a static IP. Recall that the IP address currently assigned is `10.10.11.248`. Our new static address will be `10.10.11.50` and we'll also assign the default gateway and dns-server.

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
   address 10.10.11.50
   netmask 255.255.255.0
   network 10.10.11.0
   gateway 10.10.11.1
   dns-nameservers 10.10.11.1
```

Reboot the system. Since we are ssh'ed into Ubuntu, Ubuntu server prevents us from [bouncing the network](http://askubuntu.com/questions/441619/how-to-successfully-restart-a-network-without-reboot-over-ssh). I would rather reboot anyways because in a production environment, we want 100% guarantee to know that when the system reboots our networking changes will all come-up okay.

```bash
$ sudo reboot now
```

ssh back into the server but using IP address `10.10.11.50`.

```bash
$ ssh USER@10.10.11.50
```

Are you logged back in? Great. Moving on to network interface aliases.

## eth0:0 (multiple IPs using aliases on a single network interface)

Debian-based systems allow us to assign [multiple IP addresses](https://wiki.debian.org/NetworkConfiguration#Multiple_IP_addresses_on_One_Interface) to a single interface.  These are called aliases and the format is INTERFACE:ALIAS-NUMBER (eg eth0:0, eth0:1, eth0:2). Aliases cannot have default gateway or dns-servers assigned to them. They use the gateway and dns-server of the default interface.

Open our `interfaces` file.

```bash
$ sudo vim /etc/network/interfaces
```

Modify. Let's turn the root back to a DHCP address, so gateway and dns are auto-discovered. Then we create aliases, even on different subnets, and let them use the same root interface.

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp

# alias 0 on interface eth0, re-establishing IP 10.10.11.50
auto eth0:0
iface eth0:0 inet static
    address 10.10.11.50
    netmask 255.255.255.0

# alias 1 on interface eth0, pointing to network 192.168.77.0
auto eth0:1
iface eth0:1 inet static
    address 192.168.77.1
    netmask 255.255.255.0
```

**OR** use this syntax, which is equivelent to that listed above.

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface (DHCP) w/ two alias interfaces
auto eth0
iface eth0 inet dhcp
   up   ip addr add 10.10.11.50/24 dev $IFACE label $IFACE:0
   down ip addr del 10.10.11.50/24 dev $IFACE label $IFACE:0
   up   ip addr add 192.168.77.1/24 dev $IFACE label $IFACE:1
   down ip addr del 192.168.77.1/24 dev $IFACE label $IFACE:1
```

Reboot.

```bash
$ sudo reboot now
```

ssh back into the server but using the same IP address `10.10.11.50`.

```bash
$ ssh USER@10.10.11.50
```

What does ifconfig show?

```bash
$ ifconfig
eth0      Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.248  Bcast:10.10.11.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth0:0    Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.50  Bcast:10.10.11.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth0:1    Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:192.168.77.1  Bcast:192.168.77.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0

virbr0    Link encap:Ethernet  HWaddr 6a:fe:75:50:75:8d  
          inet addr:192.168.122.1  Bcast:192.168.122.255  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
```

Looking good so far. Can we ping from the server to the public internet?

```bash
$ ping -c 3 www.google.com
PING www.google.com (74.125.225.114) 56(84) bytes of data.
64 bytes from ord08s08-in-f18.1e100.net (74.125.225.114): icmp_seq=1 ttl=52 time=18.4 ms
64 bytes from ord08s08-in-f18.1e100.net (74.125.225.114): icmp_seq=2 ttl=52 time=18.6 ms
64 bytes from ord08s08-in-f18.1e100.net (74.125.225.114): icmp_seq=3 ttl=52 time=17.6 ms

--- www.google.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 17.613/18.241/18.669/0.453 ms
```

Good. 

Can I ping the assigned interface and aliases from an external client?

We are already signed-in via ssh on IP address `10.10.11.50`, so we know that IP is valid.

What about `10.10.11.248`?

```bash
$ ping -c 3 10.10.11.248
PING 10.10.11.248 (10.10.11.248) 56(84) bytes of data.
64 bytes from 10.10.11.248: icmp_seq=1 ttl=64 time=0.446 ms
64 bytes from 10.10.11.248: icmp_seq=2 ttl=64 time=0.198 ms
64 bytes from 10.10.11.248: icmp_seq=3 ttl=64 time=0.370 ms

--- 10.10.11.248 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2000ms
rtt min/avg/max/mdev = 0.198/0.338/0.446/0.103 ms
```

Perfect. And `192.168.77.1`?

```bash
$ ping -c 3 192.168.77.1
PING 192.168.77.1 (192.168.77.1) 56(84) bytes of data.
From 192.168.77.4 icmp_seq=1 Destination Host Unreachable
From 192.168.77.4 icmp_seq=2 Destination Host Unreachable
From 192.168.77.4 icmp_seq=3 Destination Host Unreachable

--- 192.168.77.1 ping statistics ---
3 packets transmitted, 0 received, +3 errors, 100% packet loss, time 1999ms
pipe 3
```

Ouch. No luck. What happened?

This is a routing issue. My interface is part of the 10.10.11.0/24 subnet and not the subnet for 192.168.77.0/24. The Test Server's network interface card has knowledge of the 192.168.77.0/24 subnet but the network interface on the opposite end of the Test Server does not know of this subnet. Configure the external router's interface to recognize and route packets to the 192.168.77.0/24 subnet.

Since my external router is my Linux laptop, I add the route and then ping sucessfully.

```
$ sudo route add -net 192.168.77.0 netmask 255.255.255.0 br0
$ ping -c 3 192.168.77.1
PING 192.168.77.1 (192.168.77.1) 56(84) bytes of data.
64 bytes from 192.168.77.1: icmp_seq=1 ttl=64 time=0.238 ms
64 bytes from 192.168.77.1: icmp_seq=2 ttl=64 time=0.372 ms
64 bytes from 192.168.77.1: icmp_seq=3 ttl=64 time=0.207 ms

--- 192.168.77.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.207/0.272/0.372/0.072 ms
```

---

In what situations would you use interface aliases?

I use aliases all the time when I take a laptop into the field and need to connect to a router or switch. Instead of redoing the `interfaces` file, I'll actually keep the defaults but run the following command.

```bash
$ sudo ifconfig eth0:2 192.168.77.2 netmask 255.255.255.0 broadcast 192.168.77.255
$ ifconfig eth0:2
eth0:2    Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:192.168.77.2  Bcast:192.168.77.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
```

Even though the subnet is different, I have immediate connectivity because the router or switch I'm connecting with has knowledge of the different subnet. I don't need to add routes to my routing table.

I have also seen it used to map incoming requests on the edge router to a single internal web-server host. The incoming request's public static IP ending would correspond to the internal web-server's static IP ending(eg if public IP is 4.1.1.222 then internal IP would be 192.168.77.222).  Then Apache would listen to incoming requests on that IP and server pages accordingly.

## eth1 (a second network interface)

Remember that the Test Server has two physical network ports. One was auto-assigned by dev-mapper to the `eth0` interface and the second to `eth1`. Time to configure eth1.

Open the `interfaces` file.

```bash
$ sudo vim /etc/network/interfaces
```

Add eth1 as a static IP in the same 10.10.11.0/24 network.

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
   up   ip addr add 10.10.11.50/24 dev $IFACE label $IFACE:0
   down ip addr del 10.10.11.50/24 dev $IFACE label $IFACE:0
   up   ip addr add 192.168.77.1/24 dev $IFACE label $IFACE:1
   down ip addr del 192.168.77.1/24 dev $IFACE label $IFACE:1

# Secondary network interface
auto eth1
iface eth1 inet static
   address 10.10.11.60
   netmask 255.255.255.0
   network 10.10.11.0
   gateway 10.10.11.1
   dns-nameservers 10.10.11.1
```

Reboot.

```bash
$ sudo reboot now
```

ssh back into the Test Server.

```bash
$ ssh USER@10.10.11.50
```

Now ifconfig shows the eth1 interface.

```bash
$ sudo ifconfig eth1
eth1      Link encap:Ethernet  HWaddr 52:54:00:2e:52:ed  
          inet addr:10.10.11.60  Bcast:10.10.11.255  Mask:255.255.255.0
          inet6 addr: fe80::5054:ff:fe2e:52ed/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
```

Which can also be ping'ed externally.

```bash
$ ping -c 3 10.10.11.60
PING 10.10.11.60 (10.10.11.60) 56(84) bytes of data.
64 bytes from 10.10.11.60: icmp_seq=1 ttl=64 time=0.212 ms
64 bytes from 10.10.11.60: icmp_seq=2 ttl=64 time=0.328 ms
64 bytes from 10.10.11.60: icmp_seq=3 ttl=64 time=0.199 ms

--- 10.10.11.60 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.199/0.246/0.328/0.059 ms
```

## br0 (bridge), where bridge_ports = eth1

[Bridging](http://www.linuxfoundation.org/collaborate/workgroups/networking/bridge) connects two networks together to make one seemless transparent network. For our situation, this means a bridge interface can be created at the hypervisor level and then child hosts be assigned to use the hypervisor bridge interface. This will make it appear that the hypervisor and its hosts are on the same network. It operates at Level 2, only sees Ethernet frames and is protocol independent.

Both [Debian](https://wiki.debian.org/BridgeNetworkConnections) and [libvirt](http://wiki.libvirt.org/page/Networking#Altering_the_interface_config) provide advice on how to configure bridging. The instructions in this section are for the traditional way we would setup a bridge in Ubuntu, where we assign the virtual interface `br0` an IP address and make it act behave like one interface.

Open the `interfaces` file.

```bash
$ sudo vim /etc/network/interfaces
```

Create a new bridge interface and let it use the `eth1` interface directly for access to the network. Additionally, make its IP 192.168.77.1 and network 192.168.77.0/24 and remove the corresponding eth0:1 value.

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
   up   ip addr add 10.10.11.50/24 dev $IFACE label $IFACE:0
   down ip addr del 10.10.11.50/24 dev $IFACE label $IFACE:0

# Secondary network interface
auto eth1
iface eth1 inet manual

# The bridge interface
auto br0
iface br0 inet static
   address 192.168.77.1
   netmask 255.255.255.0
   network 192.168.77.0
   #ADDING OVERRIDES THE DEFAULT SET BY eth0 DHCP: gateway 192.168.77.1
   #ADDING OVERRIDES THE DEFAULT SET BY eth0 DHCP: dns-nameservers 10.10.11.1
   bridge_ports eth1
   bridge_stp on
   bridge_fd 0
   bridge_maxwait 0
```

We kept the DHCP-enabled eth0 interface. This is important because the DHCP results return our "default gateway" (eg 10.10.11.1). We don't let our bridge override those settings.

Reboot.

```bash
$ sudo reboot now
```

ssh back into the Test Server.

```bash
$ ssh USER@10.10.11.50
```

What does ifconfig look like?

```bash
$ ifconfig
$ br0     Link encap:Ethernet  HWaddr 52:54:00:2e:52:ed  
          inet addr:192.168.77.1  Bcast:192.168.77.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth0      Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.248  Bcast:10.10.11.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth0:0    Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.50  Bcast:0.0.0.0  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth1      Link encap:Ethernet  HWaddr 52:54:00:2e:52:ed  
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1

virbr0    Link encap:Ethernet  HWaddr 0e:36:67:f5:bf:1d  
          inet addr:192.168.122.1  Bcast:192.168.122.255  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
```

Is the bridge pingable from the external network? It should be. The IP remains the same. Only the nature of the interface changes to bridge.

From my external client:

```bash
$ ping -c 3 192.168.122.1
PING 192.168.122.1 (192.168.122.1) 56(84) bytes of data.
64 bytes from 192.168.122.1: icmp_seq=1 ttl=64 time=0.339 ms
64 bytes from 192.168.122.1: icmp_seq=2 ttl=64 time=0.160 ms
64 bytes from 192.168.122.1: icmp_seq=3 ttl=64 time=0.181 ms

--- 192.168.122.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.160/0.226/0.339/0.081 ms
```

## br1 (bridge) where bridge_ports = none

Now we are going to create an isolated bridge network where bridge_ports is none. We want to experiment the behavior of child hosts when they connect with this bridge.

Open the `interfaces` file.

```bash
$ sudo vim /etc/network/interfaces
```

Edit the file, adding `br1` with an IP address of 192.168.78.1 and network address of 192.168.78.0/24. 

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
   up   ip addr add 10.10.11.50/24 dev $IFACE label $IFACE:0
   down ip addr del 10.10.11.50/24 dev $IFACE label $IFACE:0

# Secondary network interface
auto eth1
iface eth1 inet manual

# The bridge interface
auto br0
iface br0 inet static
   address 192.168.77.1
   netmask 255.255.255.0
   network 192.168.77.0
   #ADDING OVERRIDES THE DEFAULT SET BY eth0 DHCP: gateway 192.168.77.1
   #ADDING OVERRIDES THE DEFAULT SET BY eth0 DHCP: dns-nameservers 10.10.11.1
   bridge_ports eth1
   bridge_stp on
   bridge_fd 0
   bridge_maxwait 0

# The bridge interface (no associated ports)
auto br1
iface br1 inet static
   address 192.168.78.1
   netmask 255.255.255.0
   network 192.168.78.0
   #ADDING OVERRIDES THE DEFAULT SET BY eth0 DHCP: gateway 192.168.78.1
   #ADDING OVERRIDES THE DEFAULT SET BY eth0 DHCP: dns-nameservers 10.10.11.1
   bridge_ports none
   bridge_stp on
   bridge_fd 0
   bridge_maxwait 0
```

What do our interfaces look like?

```bash
$ ifconfig
br0       Link encap:Ethernet  HWaddr 52:54:00:2e:52:ed  
          inet addr:192.168.77.1  Bcast:192.168.77.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

br1       Link encap:Ethernet  HWaddr 12:d1:88:24:70:a5  
          inet addr:192.168.78.1  Bcast:192.168.78.255  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1

eth0      Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.248  Bcast:10.10.11.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth0:0    Link encap:Ethernet  HWaddr 52:54:00:87:a5:22  
          inet addr:10.10.11.50  Bcast:0.0.0.0  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

eth1      Link encap:Ethernet  HWaddr 52:54:00:2e:52:ed  
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1

virbr0    Link encap:Ethernet  HWaddr a6:2f:80:62:04:c2  
          inet addr:192.168.122.1  Bcast:192.168.122.255  Mask:255.255.255.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
```

Is it pingable from the external host?

```bash
$ sudo route add -net 192.168.78.0 netmask 255.255.255.0 br0
$ ping -c 3 192.168.78.1
PING 192.168.78.1 (192.168.78.1) 56(84) bytes of data.
64 bytes from 192.168.78.1: icmp_seq=1 ttl=64 time=0.273 ms
64 bytes from 192.168.78.1: icmp_seq=2 ttl=64 time=0.207 ms
64 bytes from 192.168.78.1: icmp_seq=3 ttl=64 time=0.134 ms

--- 192.168.78.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.134/0.204/0.273/0.059 ms
```

Yes, but we had to add the route to the external device's routing table.

## Adding Uncomplicated Firewall (ufw)

To this point we have not discussed protection of the server using firewall rules. Linux uses `iptables` and `ip6tables` to manipulate the firewall packet forwarding tables. We can look at the current iptables configuration using the `iptables -L` command.

```bash
$ sudo iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     udp  --  anywhere             anywhere             udp dpt:domain
ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:domain
ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootps
ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:bootps

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             192.168.122.0/24     ctstate RELATED,ESTABLISHED
ACCEPT     all  --  192.168.122.0/24     anywhere            
ACCEPT     all  --  anywhere             anywhere            
REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable
REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootpc
```

As we see, libvirt's auto-installation of the virbr0 bridge setup iptables rules for the 192.168.122.0/24 network. But did it do so for ip6tables?

```bash
$ sudo ip6tables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
```

No, ip6tables rules were not applied.

---

Uncomplicated Firewall (ufw) is a utility that simplifies iptables and ip6tables under a single-unified command interface. It is much simpler to setup my firewall using `ufw` than iptables/ip6tabels. Let's run some tests to see how ufc effects our existing network interfaces.

Enable the firewall and view its status.

```bash
$ sudo ufw enable
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip
```

The firewall rules were applied for both IPv4 and IPv6. You can verify by viewing the results of `sudo iptables -L` and `sudo ip6tables -L`. 

Also the `ufw status verbose` results told us that all incoming packets to the Test Server were now being blocked.  However, incoming ping requests are still allowed. Pinging the existing Test Server interfaces from an external device will show successful results.

```bash
# ALL ARE SUCCESFUL, returning SUCCESSFUL PING results
$ ping -c 3 10.10.11.248
$ ping -c 3 10.10.11.50
$ ping -c 3 192.168.77.1
$ ping -c 3 192.168.78.1
$ ping -c 3 192.168.122.1
PING 192.168.122.1 (192.168.122.1) 56(84) bytes of data.
64 bytes from 192.168.122.1: icmp_seq=1 ttl=64 time=0.305 ms
64 bytes from 192.168.122.1: icmp_seq=2 ttl=64 time=0.133 ms
64 bytes from 192.168.122.1: icmp_seq=3 ttl=64 time=0.136 ms

--- 192.168.122.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.133/0.191/0.305/0.081 ms
```

Ok, but is the ssh port 22 open? Let's run `nmap` from external devices.

```bash
$ nmap -Pn -p 22 10.10.11.248
$ nmap -Pn -p 22 10.10.11.50
$ nmap -Pn -p 22 192.168.77.1
$ nmap -Pn -p 22 192.168.78.1
$ nmap -Pn -p 22 192.168.122.1

Starting Nmap 6.40 ( http://nmap.org ) at 2014-11-02 21:45 CST
Nmap scan report for 192.168.122.1
Host is up.
PORT   STATE    SERVICE
22/tcp filtered ssh

Nmap done: 1 IP address (1 host up) scanned in 2.02 seconds
```

`nmap` makes it appear that port 22 is open but in fact the state of all **incoming** ufw packets is **deny** and not reject. **Deny** will silently drop the packets, which causes client connections to time-out. 

From the external device, open a new ssh to the Test Server. (Or, if logging out or rebooting the server, you will need means to access the server to open the appropriate ufw ssh port to incoming packets.)


```bash
$ ssh avatar@10.10.11.248
^C
```

This command fails. It hangs.

Get back into the Test Server. Let's change the incoming packet rules for `ssh` to **reject**, just to demonstrate the difference than **deny**.

```bash
$ sudo ufw reject ssh
Rule added
Rule added (v6)
```

From the external client, try ssh again.

```bash
$ ssh avatar@10.10.11.248
ssh: connect to host 10.10.11.248 port 22: Connection refused
```

Good. That's what we expect.

Now let's enable ssh on the Test Server and check on its status.

```bash
$ sudo ufw allow ssh
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22                         ALLOW IN    Anywhere
22 (v6)                    ALLOW IN    Anywhere (v6)
```

We can now ssh back into the Test Server.

---

At this point, we know `ufw` works with the existing bridges. But we don't know the exact nature of how `ufw` might work with client hosts, which we will create next. Therefore, let's reset the ufw rules back to the way they were before we used ufw. This will include a reboot.

```bash
$ sudo ufw reset
$ sudo reboot now
```

ssh back into the Test Server. The `iptables -L` command will match the one we ran earlier.

```bash
$ sudo iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     udp  --  anywhere             anywhere             udp dpt:domain
ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:domain
ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootps
ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:bootps

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     all  --  anywhere             192.168.122.0/24     ctstate RELATED,ESTABLISHED
ACCEPT     all  --  192.168.122.0/24     anywhere            
ACCEPT     all  --  anywhere             anywhere            
REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable
REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootpc
```

## Create VM hosts inside the Test Server

We want to create two VM hosts within the Test Server. Their IP addresses will change depending on the scenario we desire to test. The hosts will be derived from a template.

* host1: 192.168.77.2 using network interface br0
* host2: 192.168.77.3 using network interface br0

Each VM will allocate 4096 MB of hard drive space and 1024 RAM.

---

We use [virsh](http://libvirt.org/sources/virshcmdref/html/) to manage VM guests and the hypervisor. 

Commands can be run in series, such as:

```bash
$ sudo virsh pool-list --all
 Name                 State      Autostart 
-------------------------------------------
```

Or login to `virsh`, like one would with a database or shell program and issue virsh-only commands.

```bash
$ sudo virsh
Welcome to virsh, the virtualization interactive terminal.

Type:  'help' for help with commands
       'quit' to quit

virsh # pool-list --all
 Name                 State      Autostart 
-------------------------------------------
```

Logout of virsh.

```bash
virsh # quit
```

---

On Ubuntu 14.04, the libvirt directory does not have a default storage directory in which storage pool definitions will be kept. Create that directory now.

```bash
$ sudo mkdir /etc/libvirt/storage
```

Open a new pool definition for editing.

```bash
$ sudo vim /etc/libvirt/storage/pool0.xml
```

Add the following.  Notice the UUID element is missing. We will let virsh auto-create this value.

```xml
<pool type='dir'>
  <name>pool0</name>
  <capacity unit='bytes'>0</capacity>
  <allocation unit='bytes'>0</allocation>
  <available unit='bytes'>0</available>
  <source>
  </source>
  <target>
    <path>/var/kvm/images</path>
    <permissions>
      <mode>0711</mode>
      <owner>-1</owner>
      <group>-1</group>
    </permissions>
  </target>
</pool>
```

Create the directory where the libvirt storage pool images will be kept. This matches the `<path>` element in `pool0.xml`.

```bash
$ sudo mkdir -p /var/kvm/images
```

Define the pool using virsh.

```bash
$ sudo virsh pool-define /etc/libvirt/storage/pool0.xml
Pool pool0 defined from /etc/libvirt/storage/pool0.xml
```

Verify the pool was created.

```bash
$ sudo virsh pool-list --all
 Name                 State      Autostart 
-------------------------------------------
 pool0                 inactive   no        
```

And initialized with an UUID value.

```bash
$ sudo virsh pool-info pool0
Name:           pool0
UUID:           bc1094a9-e1f1-408d-b049-6d4962a41b5f
State:          inactive
Persistent:     yes
Autostart:      no
```

Start the pool because it is currently inactive.

```bash
$ sudo virsh pool-start pool0
Pool pool0 started
```

And schedule it to auto-start on reboot.

```bash
sudo virsh pool-autostart pool0
Pool pool0 marked as autostarted
```

Check to see if it is now running and auto-start is true.

```bash
$ sudo virsh pool-info pool0
Name:           pool0
UUID:           bc1094a9-e1f1-408d-b049-6d4962a41b5f
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       25.47 GiB
Allocation:     1.95 GiB
Available:      23.51 GiB
```

---

> Note: Server World had two posts that were helpful in the following instructions. Please see [post 1](http://www.server-world.info/en/note?os=Ubuntu_14.04&p=kvm&f=2) and [post 2](http://www.server-world.info/en/note?os=Ubuntu_14.04&p=initial_conf). I had success running the "virt-install" command within the hypervisor directly installed on hardware and then copying both the image and xml definition into my nested child Test Server VM. I unsucessfully ran virt-install from within the nested VM hypervisor, where each time the creation process hung at random points. The unsucessful attempts persisted even after I instructed the Test Server VM hypervisor to emulate the physical hardware of my laptop. You will not have this problem if the Test Server hypervisor is not a virtual machine itself but is part of the bare-bones install. 

We will create a VM image to serve as our VM template from which we will clone our two hosts.

Do you have an ISO image of Ubuntu Server 14.04 available?  If not, download with `wget` or from an external device `scp` it to the Test Server.

```bash
$ scp ubuntu-14.04.1-server-amd64.iso USERNAME@10.10.11.248:~/ubuntu-server.iso
ubuntu-14.04.1-server-amd64.iso                   100%  572MB 114.4MB/s   00:05 
```

Then I moved it to the /var/kvm directory.

```bash
$ sudo mv ~/ubuntu-server.iso /var/kvm/ubuntu-server.iso
```

Create the VM template which we are naming "template1". Size is in Gigabytes. The network is set to br0. Extra arguments are passed in so we can access it from the terminal. See the [virt-install](http://linux.die.net/man/1/virt-install) for all options.

```bash
$ sudo virt-install \
			--name template1 \
			--ram 1024 \
			--disk path=/var/kvm/images/template1.img,size=4 \
			--vcpus 1 \
			--os-type linux \
			--os-variant ubuntutrusty \
			--network bridge=br0 \
			--graphics none \
			--location /var/kvm/ubuntu-server.iso \
			--console pty,target_type=serial \
			--extra-args 'console=ttyS0,115200n8 serial'
```

The install proceeds over the terminal. 

To switch from the host terminal to the Test Server:

```bash
$ ctrl-]
```

To connect back from the Test Server to the running child host.

```bash
$ sudo virsh console template1
```

---

Within the child host template, install nginx. We will use nginx to verify a working website when testing our firewall rules.

```bash
$ sudo apt-get install nginx
```

Shutdown the host.

```bash
$ sudo shutdown -h now
```

Check that the VM is "shut off".

```bash
$ sudo virsh list --all
 Id    Name                           State
----------------------------------------------------
 -     template1                     shut off
```

---

Create the two host VMs using [virt-clone](http://linux.die.net/man/1/virt-clone). 

First create `host1`.

```bash
$ sudo virt-clone --original template1 --name host1 --file /var/kvm/images/host1.img
Allocating 'host1.img'                                    | 4.0 GB     00:18     

Clone 'host1' created successfully.
```

And now `host2`.

```bash
$ sudo virt-clone --original template1 --name host2 --file /var/kvm/images/host2.img
Allocating 'host2.img'                                    | 4.0 GB     00:18     

Clone 'host2' created successfully.
```

Check the state of the VMs, which should all be "shut off".

```bash
$ sudo virsh list --all
 Id    Name                           State
----------------------------------------------------
 -     host1                          shut off
 -     host2                          shut off
 -     template1                      shut off
```

For comparison of changes made between definition files, here is the results of difference test between host1.xml and template1.xml.

```bash
$ sudo diff --side-by-side --suppress-common-lines /etc/libvirt/qemu/template1.xml /etc/libvirt/qemu/host1.xml
  virsh edit template1                                |   virsh edit host1
  <name>template1</name>                              |   <name>host1</name>
  <uuid>69a3f997-082c-e0aa-c613-8ce3f104d438</uuid>   |   <uuid>0567ce61-c0eb-d58d-44b5-3ff649b06e95</uuid>
      <source file='/var/kvm/images/template1.img'/>  |       <source file='/var/kvm/images/host1.img'/>
      <mac address='52:54:00:70:7c:de'/>              |       <mac address='52:54:00:cc:7c:fe'/>
```

As we can see `virt-clone`, created a new UUID and MAC address for the new host. This is good for us because all we need to do to activate networking is to boot-up each host and change the IP address and hostname so they will not conflict on the local network.
