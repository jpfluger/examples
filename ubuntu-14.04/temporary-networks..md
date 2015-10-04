> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Temporary Networks

Temporary network configurations are just that, temporary, and *not persistent* after reboot. This becomes useful to test a connection before saving it to `/etc/network/interfaces` or when configuring routers and switches via an ethernet management port.

## IP Interface Inpersistent

Add an IP address to an interface that does not have an IP address. If multiple IPs are to be assigned to a single interface, then use network aliases (descrbed below).

```bash
$ sudo ip addr add 192.168.1.10/24 netmask 255.255.255.0 dev eth0
```

Delete an IP address.

```bash
$ sudo ip addr del 192.168.1.10/24 dev eth0
```

If changing the IP address is desired, first delete the address then add a new one.

## IP Alias Inpersistent

An alias is the second IP address assigned to the same network interface. The `label` parameter is followed by the alias name.

```bash
$ sudo ip addr add 192.168.2.10/24 dev eth0 label eth0:0
```

Delete the address.

```bash
$ sudo ip addr del 192.168.2.10/24 dev eth0 label eth0:0
```

## VLAN Installation

VLANs originate from the IEEE 802.1q [specification](http://www.ieee802.org/1/pages/802.1Q.html). 

Install `vlan` in Ubuntu.

```bash
$ sudo apt-get install vlan
```

Is th 8021q driver already loaded?

```bash
$ lsmod | grep 8021q
8021q                  28933  0 
garp                   14384  1 8021q
mrp                    18778  1 8021q
```

If not, Load the driver. No reboot is required but note this module load will not be persistent across reboots. See the "VLAN Persistance" section below for making the VLAN install permanent.

```bash
$ sudo modprobe 8021q
```

# VLAN Configuration (Inpersistent)

Inform the kernel of the VLAN number added to a network interface.

```bash
$ sudo vconfig add eth0 5
```

Assign an address to VLAN 5.

```bash
$ sudo ip addr add 192.168.1.10/24 dev eth0.5
```

## VLAN Persistance

In order to make persistent, run the following to load `8021q` on boot.

```bash
$ sudo su -c 'echo "8021q" >> /etc/modules'
```

Save persistent VLAN configurations in `/etc/network/interfaces`.

```
auto eth0.5
iface eth0.5 inet static
    address 192.168.1.10
    netmask 255.255.255.0
    vlan-raw-device eth0
```

## Routes

What routes are configured?

```bash
# table form
$ sudo netstat -rn
# beginning of a record is the pattern used for command reference
# eg "ip route del PATTERN" or "ip route replace PATTERN"
$ sudo ip route list
```

Replace the default gateway, assuming a default gateway of `192.168.1.1`.

```bash
$ sudo ip route replace default via 192.168.1.1
```

Route a network through a network interface (eg `eth0` or bridge, like `br0`).

```bash
$ sudo ip route add 192.168.2.0/24 dev eth0
```

Specify a static route through a default gateway.

```bash
# to a subnet
$ sudo ip route add 10.0.0.1/12 via 192.168.2.1 dev eth0 src 192.168.1.10
# to a single host
$ sudo ip route add 10.0.0.1/32 via 192.168.2.1 dev eth0 src 192.168.1.10
```

Delete a route.

```bash
$ sudo ip route delete 192.168.2.0/24 dev eth0
```

## Other useful networking commands

Enable an interface.

```bash
$ sudo ip link set eth0 up
```

Disable an interface.

```bash
$ sudo ip link set eth0 down
```

List interfaces. `ip addr` is Layer 3. `ip link` is Layer 2.

```bash
$ sudo ip addr show
$ sudo ip link show
```

> Note: for those familiar with `ifconfig`, this command has been [deprecated](http://serverfault.com/questions/458628/should-i-quit-using-ifconfig) for some time. 

