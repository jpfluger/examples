> Back to [Table of Contents](https://github.com/jpfluger/examples)

# kvm

Before installing kvm, answer this question: "Can this hardware or VM instance run kvm?" The answer can be found in Ubuntu's [pre-installation checklist](https://help.ubuntu.com/community/KVM/Installation).

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

## Identify Primary Interface

For most devices, network connectivity begins by enabling WIFI or plugging in a physical connecter (eg RJ-45 jack) to a network card.

Ubuntu uses [udev](http://manpages.ubuntu.com/manpages/trusty/man7/udev.7.html) to know manage software device events, such as mapping physical hardware to software.

Get a list of physical hardware attached to this machine.

```bash
$ lspci

# OR filter by term (e.g. "ethernet" or "wireless")... case insensitive search
$ lspci | grep -i ethernet
$ lspci | grep -i wireless
```

In the list you will see a hardware address followed by a description. Here are my lspci values for my network card and wireless card:

```
03:00.2 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller (rev 0a)
04:00.0 Network controller: Intel Corporation Wireless 7260 (rev 73)
```

Now in the udev logs, we can search for devices mapped to interfaces by the pci number associated with the device.

```bash
$ grep -i \(net\) /var/log/udev | sort -u
KERNEL[4.930302] add      /devices/pci0000:00/0000:00:1c.2/0000:03:00.2/net/eth0 (net)
KERNEL[4.935173] add      /devices/virtual/net/lo (net)
KERNEL[5.389799] add      /devices/pci0000:00/0000:00:1c.3/0000:04:00.0/net/wlan0 (net)
UDEV  [4.976511] add      /devices/pci0000:00/0000:00:1c.2/0000:03:00.2/net/eth0 (net)
UDEV  [5.100427] add      /devices/virtual/net/lo (net)
UDEV  [5.398651] add      /devices/pci0000:00/0000:00:1c.3/0000:04:00.0/net/wlan0 (net)
```

These results show we have interfaces for `lo`, `eth0` and `wlan0`. Notice the pci device points grep'ed from lspci are within the device path. 

> Note: If anyone knows a better one-liner command that gives me physical-to-interface results, please let me know!

To explore network hardware details, please see the examples on [linuxnix.com](http://www.linuxnix.com/2013/06/find-network-cardwiredwireless-details-in-linuxunix.html).

## Installation

Install the following packages.

```bash
$ sudo apt-get install qemu-kvm libvirt-bin bridge-utils virt-manager virt-viewer spice-client-gtk spice-client ubuntu-vm-builder qemu-system
```

Add to user groups.

```bash
$ sudo adduser `id -un` libvirtd
$ sudo adduser `id -un` kvm
```

