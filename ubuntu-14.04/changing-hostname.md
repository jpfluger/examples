> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Changing the hostname

## Assess the current name

There might be a need to change the hostname on the server. First let's see what the current fully-qualified-domain-name is:

```bash
$ hostname -f
```

If the [prior example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/updates-ssh-static-ip.md) was followed, this should return a fqdn, like:

```bash
svr1.example.com
```

But sometimes the domain name isn't set, which I've seen when converting an Ubuntu 14.04 desktop to an Ubuntu 14.04 server and the results from `hostname -f` would be:

```bash
svr1
```

And from `hostname -y`, which returns the domain name portion only:

```
hostname: Local domain name not set
```

## Change the name

We need to determine that two files are setup correctly. 

The file that contains the name of the server is `/etc/hostname`. Let's open that file:

```bash
$ sudo vim /etc/hostname
```

Feel free to change the name of the server here. You do not need to add on the domain name. The single name of the server is sufficient.

```bash
svr1
```

Restart hostname, in order for the new hostname to be recognized by current system without a reboot.

```bash
$ sudo service hostname restart
```

The file responsible for the fqdn and direct ip-to-fqdn mappings is `/etc/hosts`. The server looks here first, before ever consulting DNS. If you desire to trick your computer to thinking that www.google.com is your own computer, then this is the place to do it. But for our purposes, we want to use DNS and are only checking to ensure our server has the correct fqdn locally.

Open the file:

```bash
$ sudo vim /etc/hosts
```

Edit your ip-to-fqdn mappings. In order for the fqdn to be recognized, it must be placed before the short-name.

```bash
127.0.0.1       localhost
127.0.1.1       svr1.example.com sv1
```

## Reassess the current name

Run this again.

```bash
$ hostname -f
```

And you should see your desired name.

```bash
svr1.example.com
```