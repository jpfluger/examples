# First updates, openssh-server and DHCP to Static IP

> [Table of Contents](https://github.com/jpfluger/examples)

First provision a server using Ubuntu 14.04 Server. During install, choose network access via DHCP and input your server name, domain, username and password. 

* FQDN: svr1.example.com (Name=svr1, Domain=example.com)
* IP: 192.168.1.2 (During setup use DHCP; we'll set the static ip later)
* USER: myname
* PASS: mypassword

---

After the system reboots, you will login for the first time. Run the following commands now and then in the future to bring the system up-to-date.

```bash
sudo apt-get update
sudo apt-get upgrade
```

Run these for a distribution upgrade (eg 14.04 to 14.04 r2)

```bash
sudo apt-get dist-upgrade
```

---

Install the ssh server.

```bash
sudo apt-get install openssh-server
```

You might be prompted to autoremove packages or update grub.

```bash
sudo apt-get autoremove
sudo update-grub
```

---

Install a command-line editor. All examples here will use `vim` but if you are not familiar with command-line editors, use `nano`. Nano will have its commands listed as a menu at the bottom of the window. To use nano, simply swap out `vim` for `nano` in the examples below. In nano, press `ctrl-X` to exit and when nano asks if you want to save, answer yes.

```bash
sudo apt-get install vim
sudo apt-get install nano
```

---

Check out the IP address.

```bash
ifconfig
```

---

To setup a static IP, open the following file with your favorite command-line editor. Use sudo for these commands because root access is needed to change ip configurations.

```bash
sudo vim /etc/network/interfaces
```

Delete or use # to comment out the two lines for dhcp and add the following for static ip. The full file looks like this:

```bash
auto lo
iface lo inet loopback

#auto eth0
#iface eth0 inet dhcp

auto eth0
iface eth0 inet static
   address 192.168.1.2
   netmask 255.255.255.0
   network 192.168.1.0
   gateway 192.168.1.1
   dns-nameservers 192.168.1.10
```

Restart the server. We are restarting the server rather than restarting network services because if you are running these commands via ssh, the results are guaranteed to cleanly exit the remote ssh session.

```bash
sudo shutdown -r now
```

---

Log back into the server. Check out the IP address to make certain it is correct.

```bash
ifconfig
```

---

Make certain the network DNS server has an entry for svr1.example.com.
