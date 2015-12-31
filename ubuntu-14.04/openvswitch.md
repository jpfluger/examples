> Back to [Table of Contents](https://github.com/jpfluger/examples)

# OpenVSwitch

[OpenVSwitch](http://openvswitch.org/) (aka OVS) is a multilayer virtual switch specifically designed to support production virtual machines environments. Yes, that was a mouthful, wasn't it?  If one breezed over OVS's [website](http://openvswitch.org/) or OVS's [entry](https://en.wikipedia.org/wiki/Open_vSwitch) on Wikipedia, one would notice some images that help to understand the architectural paradigm. (Wow, another mouthful, "architectural paradigm!")

For our purposes, what we need to know is that OVS is first setup to support Layer 2 of the [OSI Model](https://en.wikipedia.org/wiki/OSI_model). We can create VLANs, access ports and trunks. In addition we can apply Layer 3 interfaces (eg ip address) to a Layer 2 object. In networking parlance, this would be called adding a "routing interface" because Layer 3 is where routing happens. OVS supports manipulation of data higher in the OSI Model (Layers 4 to 7, including Quality of Service shaping and queuing, Traffic Filtering, Flow Manipulation and Monitoring) but this guide does not address these.

This guide will discuss how to replace traditional Linux bridging with OVS and how to instruct virtual machine instances to use OVS. 

> ATTENTION! Many tutorials exist on the internet showing Debian/Ubuntu configuration with OVS. Not many use the OVS commands that can be written directly into `/etc/network/interfaces`. This tutorial does that. Indispensable to this tutorial are [Proxmox's guide for OVS](https://pve.proxmox.com/wiki/Open_vSwitch) and the [OVS Debian README](http://git.openvswitch.org/cgi-bin/gitweb.cgi?p=openvswitch;a=blob_plain;f=debian/openvswitch-switch.README.Debian).

## Installation

Install a clean copy of Ubuntu Server 14.04, which will be used as the hypervisor. Ensure the system is up-to-date and an ssh server has been installed, although don't access the machine through ssh just yet, since the network connection will be dropped during reconfiguration.

```bash
$ apt-get update && apt-get upgrade
$ sudo apt-get dist-upgrade
$ sudo apt-get install openssh-server
```

Next install OVS and KVM.

```bash
$ sudo apt-get install openvswitch-switch qemu-kvm libvirt-bin
```

## Clear OVS on Reboot

Since we will be letting Ubuntu implement OVS via `/etc/network/interfaces` instead of using `ovs-ctl` commands, we need to instruct Ubuntu on restart to clear the OVS tables, so they may be refreshed with the parameters supplied in `/etc/network/interfaces`.

Open the OVS defaults file in a text editor.

```bash
$ sudo vim /etc/default/openvswitch-switch
```

Add `--delete-bridges` to the options line.

```vim
# OVS_CTL_OPTS: Extra options to pass to ovs-ctl.  This is, for example,
# a suitable place to specify --ovs-vswitchd-wrapper=valgrind.
OVS_CTL_OPTS='--delete-bridges'
```

Per [this guide](http://www.opencloudblog.com/?p=240), patch the OVS upstart script.

First open the script.

```bash
$ sudo vim /etc/init/openvswitch-switch.conf
```

The edits appear in **two** places defined by `PATCH-START` and `PATCH-END`.

```
  set ovs_ctl start --system-id=random
  if test X"$FORCE_COREFILES" != X; then
    set "$@" --force-corefiles="$FORCE_COREFILES"
  fi
  set "$@" $OVS_CTL_OPTS
  ##### PATCH-START
  "$@" || exit $?
  bridges=`ifquery --allow ovs -l`
  [ -n "${bridges}" ] && ifup --allow=ovs ${bridges}
  logger -t ovs-start pre-start end
  ##### PATCH-END
end script

post-stop script
  ##### PATCH-START #####
  logger -t ovs-stop post-stop
  bridges=`ifquery --allow ovs -l`
  [ -n "${bridges}" ] && ifdown --allow=ovs ${bridges}
  ##### PATCH-END #####
  . /usr/share/openvswitch/scripts/ovs-lib
  test -e /etc/default/openvswitch-switch && . /etc/default/openvswitch-switch

  ovs_ctl stop
end script
```

## NIC Port Names

Traditionally eth0 and eth1 have been designated by Linux as the standard port interfaces for ethernet port 1 and 2 (LAN 1 and LAN 2). Recently, [Dell](http://www.arachnoid.com/linux/network_names/index.html) and [RedHat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Deployment_Guide/appe-Consistent_Network_Device_Naming.html) decided to rename these to correspond to the piece of hardware on which the reside and function. Ubuntu decided to follow along with the new convention, so eth0 became p4p1 and eth1 became em1. 

But there is a perfectly acceptable way to use the old names, and because I think readers are more familiar with eth0/eth1, I'll show how to revert to this naming convention.

First open the settings for `grub`.

```bash
$ sudo vim /etc/default/grub
```

Add `biosdevname=0` to two options.

```bash
GRUB_CMDLINE_LINUX_DEFAULT="biosdevname=0"
GRUB_CMDLINE_LINUX="biosdevname=0"
```

Save and then update grub.

```bash
$ sudo update-grub
```

> Note: Does `/etc/network/interfaces` contain the syntax for the old names (eg `p4p1` or `em1`)?  If so, rename these to the traditional nomenclature otherwise you will lose network connectivity after reboot.

Open the `interfaces` file.

```bash
$ sudo vim /etc/network/interfaces
```

Swap out names.

```vim
# The loopback network interface
auto lo
iface lo inet loopback

# p4p1
#auto p4p1
#iface p4p1 inet static
#       address 192.168.1.25
#       netmask 255.255.255.0
#       gateway 192.168.1.1

# p4p1 (new nomenclature) renamed to eth0 (traditional nomenclature) after setting "biosdevname=0" option in grub
auto eth0
iface eth0 inet static
       address 192.168.1.25
       netmask 255.255.255.0
       gateway 192.168.1.1
```

Save the file.

Reboot. Test your network connection. Everything should be working normally.

## Single Port, Multiple VLANs

The switch connected to the server should be configured in "trunk" mode. 

```vim
# The loopback network interface
auto lo
iface lo inet loopback

# Bridge for our bond and vlan virtual interfaces (our VMs will also attach ot this bridge)
auto vmbr0
allow-ovs vmbr0
iface vmbr0 inet manual
        ovs_type OVSBridge
        ovs_ports eth0 vlan31 vlan32

# Phyiscal traffic interface for traffic coming into the system.
#auto eth0
allow-vmbr0 eth0
iface eth0 inet manual
        ovs_bridge vmbr0
        ovs_type OVSPort
        ovs_options tag=31 vlan_mode=native-untagged trunks=31,32

# Virtual interface for COMM-MGMT
allow-vmbr0 vlan31
iface vlan31 inet static
        ovs_type OVSIntPort
        ovs_bridge vmbr0
        ovs_options tag=31
        ovs_extra set interface ${IFACE} external-ids:iface-id=$(hostname -s)-${IFACE}-vif
        address 192.168.1.10
        netmask 255.255.255.0
        gateway 192.168.1.1
        dns-nameservers 208.67.222.222 208.67.220.220

# Virtual interface for COMM-DMZ        
allow-vmbr0 vlan32
iface vlan32 inet static
        ovs_type OVSIntPort
        ovs_bridge vmbr0
        ovs_options tag=32
        # if vlan32 should only be a Layer 2 switch and not having a routing interface instance, then comment out the following lines
        ovs_extra set interface ${IFACE} external-ids:iface-id=$(hostname -s)-${IFACE}-vif
        address 192.168.2.25
        netmask 255.255.255.0
        gateway 192.168.2.1
```

> Note:  `vlan32` has a layer 3 interface set. When this happens Linux (and OVS) do not block routing between VLANs on the hypervisor. To stop this, simply remove the Layer 3 interface settings from the `vlan32` interfaces configuration. (See comments within the interfaces file above.) Then any VM attached to this layer will be sent to the connected router for instruction on where to go rather than be routed through the hypervisor.

## Get the Image to use for the VM

Have the image of the desired VM ready. Either download from the internet or copy over from another computer.

To download Ubuntu Server 14.04 from the internet, open a web browser to `http://releases.ubuntu.com/14.04/`. Locate the desired image and download using `wget`.

```bash
# To download Ubuntu Server 14.04
$ wget http://releases.ubuntu.com/14.04/ubuntu-14.04.3-server-amd64.iso
```

Or if the image is on a different computer, one option is to use `scp` to transfer the file.

```bash
# From computer 2, sending to the hypervisor /home directory
$ scp ubuntu-14.04.3-server-amd64.iso avatar@192.168.1.1:~/
```

## Configure the VM Storage Pool

Configure the [storage pool](https://libvirt.org/storage.html), which provides support to many different storage types (eg iSCSI or NFS). In the example below, create a storage pool for ISO images and a second for instance images.

> Note: You can do this through the Virtual Machine Manager GUI on a different computer. Simply connect to the remote hypervisor over ssh through the VM Manager GUI.

Make a directory for configurations and where the storage pools will reside.

```bash
$ mkdir /home/avatar/config
$ mkdir /home/avatar/isos
$ mkdir /home/avatar/vms
```

Open `isos.xml` for editing.

```bash
$ vim /home/avatar/config/isos.xml
```

Edit the file.

```xml
<pool type='dir'>
  <name>isos</name>
  <capacity unit='bytes'>0</capacity>
  <allocation unit='bytes'>0</allocation>
  <available unit='bytes'>0</available>
  <source>
  </source>
  <target>
    <path>/home/avatar/isos</path>
    <permissions>
      <mode>0711</mode>
      <owner>-1</owner>
      <group>-1</group>
    </permissions>
  </target>
</pool>
```

Open `images.xml` for editing.

```bash
$ vim /home/avatar/config/vm-images.xml
```

Edit the images storage pool file.

```xml
<pool type='dir'>
  <name>vm-images</name>
  <capacity unit='bytes'>0</capacity>
  <allocation unit='bytes'>0</allocation>
  <available unit='bytes'>0</available>
  <source>
  </source>
  <target>
    <path>/home/avatar/vm-images</path>
    <permissions>
      <mode>0711</mode>
      <owner>-1</owner>
      <group>-1</group>
    </permissions>
  </target>
</pool>
```

Create a new storage pool by importing these into the virtual system.

```bash
$ virsh pool-define config/isos.xml
$ virsh pool-define config/vm-images.xml
```

Set the autostart property to yes and make the state active.

```bash
$ sudo virsh pool-start isos
$ sudo virsh pool-start vm-image
$ sudo virsh pool-autostart isos
$ sudo virsh pool-autostart vm-image
```

Verify the pool was created and autostart is yes.

```bash
$ virsh pool-list --all
 Name                 State      Autostart 
-------------------------------------------
 default              active     yes       
 isos                 active     yes       
 vm-images            active     yes      
```

## Create a libvirt Network

Is libvirt another network separate from OVS? Yes, libvirt manages the networks for the VMs. Is it possible to assign an OVS Port, like `vlan31`, directly to a VM?  No, not an OVS port. But we do assign the OVS bridge to be used by libvirt. See p5ntangle's [article](https://zacloudbuilder.wordpress.com/2013/08/20/openvswitch-and-kvm-with-libvirt/) (and great graphic!) that discusses these kvm, libvirt and OVS.

> Note: Even though we define vlans and trunks a second time, libvirt uses this file is used by libvirt to manage host interactions with OVS. Towards the end of this tutorial is output showing output of OVS and routing tables.

Create the file.

```bash
$ vim config/vmbr0.xml
```

Edit it.

```xml
<network>
  <name>libvirt-vmbr0</name>
  <forward mode='bridge'/>
  <bridge name='vmbr0'/>
  <virtualport type='openvswitch'/>
  <vlan trunk='yes'>
    <tag id='31' nativeMode='untagged'/>
    <tag id='32'/>
  </vlan>
  <portgroup name='V31' default='yes'>
    <vlan>
      <tag id='31'/>
    </vlan>
  </portgroup>
  <portgroup name='V32'>
    <vlan>
      <tag id='32'/>
    </vlan>
  </portgroup>
</network>
```

Save.

Define it within libvirt, make it active and let it autostart.

```bash
$ virsh net-define config/vmbr0.xml 
$ virsh net-start libvirt-vmbr0
$ virsh net-autostart libvirt-vmbr0
```

View the results.

```bash
$ virsh net-list --all
 Name                 State      Autostart     Persistent
----------------------------------------------------------
 libvirt-vmbr0        active     yes           yes
```

The network will now be a selectable item from within Virtual Machine Manager.

## Create a Virtual Machine

At this point, we can go to a second computer and connect to the hypervisor using Virtual Machine Manager.  

1. From the menu, choose `File>Add Connection`. 
2. The hypervisor is QEMU/KVM
3. Click "Connect to remote host"
4. The method is "ssh". Enter the username and ip address.

The connection string (created for you) will look like this

```
qemu+ssh://avatar@192.168.1.10/system
```

Once the new connection is displayed in the GUI, right-click it and choose details. Flip through the tabs to ensure virtual networks and storage items are active and visible.

Click the left toolbar button to begin creating a new VM instance. Be certain to choose the remote host as the target hypervisor.

During install, I created a VM with a static IP in the same subnet as the V31 interface. From within the VM, I could sucessfully communicate to the outside network through the gateway but not with any other VMs defined on the hypervisor. And from a different computer on the same 32 VLAN, I could successfully ping the new VM but not other subnets. Good.

After a VM has been created, if its desired for the VM to autostart be certain to toggle this setting to `true` in the GUI or by command.

```bash
# command to toggle starting of VM on boot
$ virsh autostart VM-NAME
```

## Setting a Different VLAN on the Host

By default, the `libvirt-vmbr0` network we defined above has VLAN 31 as the default VLAN. To assign a different VLAN to the host, edit the VM configuration.

Edit the host file.

```bash
$ virsh edit HOST-NAME-FOR-VLAN32
```

Locate the xml element named `interfaces` with a type of `network`. Specify the portgroup, which maps to settings in `libvirt-vmbr0`.

```xml
   <interface type='network'>
      <mac address='XX:XX:XX:XX:XXX:XX'/>
      <source network='libvirt-vmbr0' portgroup='V32'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
```

Save. Restart the VM for changes to take effect.

## Output and Troubleshooting

After adding a few virtual machines, here is what my ovs-ctrl looks like. Notice how libvirt automatically added the `vnet[s]` for the VMs during each VM boot sequence. `vmbr0` is the switch, `eth0` has untagged packets tagged to 31 and accepts two trunks, `vlan31` and `vlan32` are hypervisor-specific ports that can be pinged from any source that belongs to the same subnet. `vnet[0-2]` were auto-tagged with 31. `vnet3` was tagged 32.  The vnets were added by OVS while all others (eg bridge, ports and interface ports) were defined in `/etc/network/interfaces`.

```bash
$ sudo ovs-vsctl show
XXXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX
    Bridge "vmbr0"
        Port "vlan31"
            tag: 31
            Interface "vlan31"
                type: internal
        Port "vnet3"
            tag: 32
            Interface "vnet3"
        Port "eth0"
            tag: 31
            trunks: [31, 32]
            Interface "eth0"
        Port "vlan32"
            tag: 32
            Interface "vlan32"
                type: internal
        Port "vnet2"
            tag: 31
            Interface "vnet2"
        Port "vmbr0"
            Interface "vmbr0"
                type: internal
        Port "vnet0"
            tag: 31
            Interface "vnet0"
        Port "vnet1"
            tag: 31
            Interface "vnet1"
    ovs_version: "2.0.2"
```

What does the routing table look like?

```bash
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         192.168.1.1     0.0.0.0         UG    0      0        0 vlan31
192.168.1.0     *               255.255.255.0   U     0      0        0 vlan31
192.168.20.0     *              255.255.255.0   U     0      0        0 vlan32
```

To analyze if interfaces are receiving any traffic, use `tcpdump` to inspect packets. This can be performed on an interface or vlan. 

Below is output from a tcpdump capture of interface `vlan32` getting pinged by a remote device.

```bash
$ sudo tcpdump -n -i vlan32
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on vlan32, link-type EN10MB (Ethernet), capture size 65535 bytes
21:59:23.215528 IP 192.168.2.25 > 192.168.2.10: ICMP echo request, id 3943, seq 1, length 64
21:59:23.215561 IP 192.168.2.10 > 192.168.2.25: ICMP echo reply, id 3943, seq 1, length 64
21:59:24.214528 IP 192.168.2.25 > 192.168.2.10: ICMP echo request, id 3943, seq 2, length 64
21:59:24.214555 IP 192.168.2.10 > 192.168.2.25: ICMP echo reply, id 3943, seq 2, length 64
21:59:25.214591 IP 192.168.2.25 > 192.168.2.10: ICMP echo request, id 3943, seq 3, length 64
21:59:25.214619 IP 192.168.2.10 > 192.168.2.25: ICMP echo reply, id 3943, seq 3, length 64
21:59:28.218462 ARP, Request who-has 192.168.2.25 tell 192.168.2.10, length 28
21:59:28.219055 ARP, Reply 192.168.2.25 is-at XX:XX:XX:XX:XX:XX, length 46
```

To capture a specific vlan, one would think the following might work - and on some architectures this might be true.

```bash
$ sudo tcpdump -n -i vlan32 vlan 32
```

**BUT** [there's a bug](http://serverfault.com/questions/544651/vlan-tags-not-shown-in-packet-capture-linux-via-tcpdump) on i686/x86)64 architectures due to VLAN acceleration. Thanks to [shawnzhu](http://serverfault.com/users/181282/shawnzhu), try this technique for viewing vlan-specific packets.

```bash
$ sudo tcpdump -i eth0 -Uw - | tcpdump -en -r - vlan 32
tcpdump: WARNING: eth0: no IPv4 address assigned
tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
reading from file -, link-type EN10MB (Ethernet)
XX:XX:XX.XXXXXX XX:XX:XX:XX:XX:XX > XX:XX:XX:XX:XX:XX, ethertype 802.1Q (0x8100), length 102: vlan 32, p 0, ethertype IPv4, 192.168.20.25 > 192.168.20.10: ICMP echo request, id 3947, seq 1, length 64
XX:XX:XX.XXXXXX XX:XX:XX:XX:XX:XX > XX:XX:XX:XX:XX:XX, ethertype 802.1Q (0x8100), length 102: vlan 32, p 0, ethertype IPv4, 192.168.20.10 > 192.168.20.25: ICMP echo reply, id 3947, seq 1, length 64
XX:XX:XX.XXXXXX XX:XX:XX:XX:XX:XX > XX:XX:XX:XX:XX:XX, ethertype 802.1Q (0x8100), length 102: vlan 32, p 0, ethertype IPv4, 192.168.20.25 > 192.168.20.10: ICMP echo request, id 3947, seq 2, length 64
XX:XX:XX.XXXXXX XX:XX:XX:XX:XX:XX > XX:XX:XX:XX:XX:XX, ethertype 802.1Q (0x8100), length 102: vlan 32, p 0, ethertype IPv4, 192.168.20.10 > 192.168.20.25: ICMP echo reply, id 3947, seq 2, length 64
XX:XX:XX.XXXXXX XX:XX:XX:XX:XX:XX > XX:XX:XX:XX:XX:XX, ethertype 802.1Q (0x8100), length 102: vlan 32, p 0, ethertype IPv4, 192.168.20.25 > 192.168.20.10: ICMP echo request, id 3947, seq 3, length 64
XX:XX:XX.XXXXXX XX:XX:XX:XX:XX:XX > XX:XX:XX:XX:XX:XX, ethertype 802.1Q (0x8100), length 102: vlan 32, p 0, ethertype IPv4, 192.168.20.10 > 192.168.20.25: ICMP echo reply, id 3947, seq 3, length 64
^Ctcpdump: pcap_loop: error reading dump file: Interrupted system call
22 packets captured
24 packets received by filter
0 packets dropped by kernel
```

## Connectivity with Physical Router

Remember that in the networking world, Layer 2 switches break up collisions domains and Layer 3 switches break up broadcast domains. With that in mind, know that the default gateway (eg router) must be configured to handle the trunk from the physical `eth0` port on the hypervisor. 

Not all routers are made the same, so making the interface on the router a trunk-line might not be enough though. On my Juniper SRX, if using default settings, create and add the V31 and V32 VLANS to the trust zone. If the VLANs are not added to the trust zone (or an alternative zone), the hypervisor and hosts on that VLAN won't be able to ping/communicate with the SRX device.

For example, here is a Juniper SRX port interface defining the trunk.

```
# show interfaces ge-0/0/1
unit 0 {
    family ethernet-switching {
        port-mode trunk;
        vlan {
            members [ V31 V32 ];
        }
        native-vlan-id 31;
    }
}
```

And here is the security zone.

```
# show security zones 
security-zone trust {
    host-inbound-traffic {
        system-services {
            all;
        }
        protocols {
            all;
        }
    }
    interfaces {
        vlan.31;
        vlan.32;
    }
}
```

## Fixing Password Prompts

Password prompts are common when using ssh, so according to Fedora's [documentation](https://docs.fedoraproject.org/en-US/Fedora/13/html/Virtualization_Guide/chap-Virtualization-Remote_management_of_virtualized_guests.html) there is a way to avoid the pesky password prompt.

Create the ssh pair on the client that will be connecting to the hypervisor.

```bash
$ ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (/home/nezzie/.ssh/id_rsa): /home/username/.ssh/id_rsa_virtman
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/nezzie/.ssh/id_rsa_virtman.
Your public key has been saved in /home/nezzie/.ssh/id_rsa_virtman.pub.
The key fingerprint is:
XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:X:XX:XX avatar@example.com
The key's randomart image is:
+--[ RSA 2048]----+
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
|                 |
+-----------------+
[nezzie:~]$ ssh-copy-id -i ~/.ssh/id_rsa_virtman.pub avatar@192.168.1.10
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
avatar@192.168.1.10's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'avatar@192.168.1.10'"
and check to make sure that only the key(s) you wanted were added.
```

Try ssh'ing into 192.168.1.10 and viewing the authorized file.

```bash
$ ssh avatar@192.168.1.10
$ cat .ssh/authorized_keys 
ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX avatar@example.com
```

If you used a passphrase during the creation of the rsa key, you can add this to ssh-agent on the client. This will enable password-less login.

```bash
$ ssh-add ~/.ssh/id_rsa_virtman.pub
```
