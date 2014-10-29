> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Post-Install Updates: openssh-server and DHCP to Static IP

First provision a server using Ubuntu 14.04 Server. During install, choose network access via DHCP and input your server name, domain, username and password. 

* FQDN: svr1.example.com (Name=svr1, Domain=example.com)
* IP: 192.168.1.2 (During setup use DHCP; we'll set the static ip later)
* USER: myname
* PASS: mypassword

---

After the system reboots, you will login for the first time. Run the following commands now and then in the future to bring the system up-to-date with currently installed packages.

```bash
$ sudo apt-get update
$ sudo apt-get upgrade
```

Run these for a distribution upgrade (eg 14.04 to 14.04 r2), which installs new packages (eg kernels) with dependencies and can auto-remove unused packages. This is not a system update (eg moving from Ubuntu Server 14.04 to 14.10). 

```bash
$ sudo apt-get dist-upgrade
```

> Note: For systems requiring strict adherence to a package update process, use a test system to `upgrade` and/or `dist-upgrade` servers and which automatically run tests against programs before updating production servers. 

For system updates, run:

```bash
$ sudo do-release-upgrade
```

> Note: This server is Ubuntu Server 14.04, which is a [long-term release](https://wiki.ubuntu.com/Releases) with support ending in April 2019. In a production environment, since this is a LTR, I would not run a version release upgrade unless it was tested first.

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

## Optional: change the `sudo` timeout

If you want to avoid having to enter the `sudo` password every 2 minutes, then follow these directions. After setup, remember to delete this for a production environment.

```bash
sudo visudo
```

Find the line with `Default   env_reset` and change to something else. The time is in minutes. "-1" says never use a password prompt. 43200 is 30 days worth of minutes.

```vim
Defaults    env_reset,timestamp_timeout=43200
```
