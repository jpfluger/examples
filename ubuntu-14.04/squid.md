> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Squid

Install [Squid](http://www.squid-cache.org/) on Ubuntu 14.04 and configure with the following features:

1. Restrict incoming requests by IP addresses
2. Restrict outgoing requests by domain name
3. Require the connecting client to authenticate themselves

On the Linux client, install [Cntlm Proxy](http://cntlm.sourceforge.net/) which allows for graceful communication between a local client and a corporate proxy service, like Squid or a Windows-Authenticated proxy. I added directions for this at the end of the Squid installation.

## Installation

Installation is rather straight forward. Install Squid via `apt-get`.

```bash
$ sudo apt-get install squid3
```

## Restrict incoming requests

Open Squid's configuration file for editing.

```bash
$ sudo vim /etc/squid3/squid.conf 
```

The configuration file is quite long. Search for where the access lists ("acl") are located, particularly for the keywords `acl localnet`.  When this section is discovered, add the server or servers that should be allowed to connect with this Squid instance. More access rules can be found in the Squid [wiki](http://wiki.squid-cache.org/SquidFaq/SquidAcl#ACL_elements) and [acl definitions](http://www.squid-cache.org/Doc/config/acl/).

```
# By Network Subnet
acl dmz_servers src 192.168.99.0/24
# By Single IPv4
acl single_server src 192.168.98.25
```

Then find the "http_access" section and within there is a comment, "INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS". Under this comment, add the following to allow http_access from the dmz_servers network specifed above.

```
http_access allow dmz_servers
http_access allow single_server
```

Locate the line defining the http_port listining number (e.g. search on "http_port 3128"). By default Squid listens on port 3128. Unfortunately, Squid only sets the port to listen for IPv6 addresses. Change the following to let Squid listen on IPv4 addresses as well.

```
# Squid normally listens to port 3128
http_port 0.0.0.0:3128
```

Check for errors in the configuration file.

```bash
$ sudo squid3 parse
# No errors returned is good
```

Restart services for changes to take effect.

``` bash
$ sudo service squid3 restart
```

Verify listening on port 3128.

```bash
$ sudo netstat -ntulp | grep LISTEN
tcp6       0      0 :::3128                 :::*                    LISTEN      5012/(squid-1)  
```

Woh!  Did you see that?  Squid is listining for IPv6 still. You might need to kill that process like this and then reverify.

```bash
$ sudo kill 5012
$ sudo service squid3 start
$ sudo netstat -ntulp | grep LISTEN
tcp        0      0 0.0.0.0:3128            0.0.0.0:*               LISTEN      7191/squid3     
```

Ah... that's more like it.

## Restricting website access

If we require a more full-featured solution to restrict website access, we can install [squidGuard](http://www.squidguard.org/) which will install pre-configured blacklists. See this Ubuntu [tutorial](http://www.cyberciti.biz/faq/squidguard-web-filter-block-websites/) for help.

But in this example, we only want to allow access to a single domain, so we will explicitly define the domains within the existing Squid installation.

Open the Squid configuration file.

```bash
$ sudo vim /etc/squid3/squid.conf 
```

Below the acl declaration made above (eg `acl dmz_servers`), add an acl that points to a file. This will be the file of the allowed domains.

```
acl whitelist_updates dstdomain "/etc/squid3/whitelist/updates.txt"
```

And then replace the entry for "http_access allow dmz_servers" to only serve sites found in the whitelist file and deny all others.

```
http_access allow dmz_servers whitelist_updates
http_access deny dmz_servers !whitelist_updates
```

While we're at it, let's comment in the following.

```
http_access deny to_localhost
```

Create the directory for the whitelist.

```bash
$ sudo mkdir /etc/squid3/whitelist
```

Open the whitelist file for editing.

```bash
$ sudo vim /etc/squid3/whitelist/updates.txt
```

Add allowed domains. Add a "." prefix to include subdomains. For example, ".google.coom" includes all google.com subdomains, such as www.google.com and news.google.com.

In our case, we only want the whitelist to include repositories Ubuntu needs to keep its software updated.

```
.ubuntu.com
```

Reload Squid. We will be testing this configuration later below.

``bash
$ sudo service squid3 reload
```

## Additional configurations

For configuring a cache to download and store objects, such as images and files, please see Ubuntu [help](https://help.ubuntu.com/community/Squid) or the Squid [wiki](http://wiki.squid-cache.org/SquidFaq/ConfiguringSquid#What_.27.27cache_dir.27.27_size_should_I_use.3F).

For configuring squid to authenticate users, please search the web. Some results are listed below.

  * [Basic Authentication](http://stackoverflow.com/questions/3297196/how-to-set-up-a-squid-proxy-with-basic-username-and-password-authentication)
  * [LDAP](https://workaround.org/squid-ldap)
  * [Active Directory](http://wiki.squid-cache.org/ConfigExamples/Authenticate/WindowsActiveDirectory)

## Cntlm Proxy

Login to an Ubuntu client that is to use Squid as its web-proxy. My client is located in a DMZ and only needs outbound access to DNS and the Ubuntu APT repositores. 

Install [Cntlm Proxy](http://cntlm.sourceforge.net/), which is used on the client to communicate with a corporate proxy server, which in our case is Squid.

``` bash
$ apt-get install cntlm
```

Open the cntlm configuration file.

```bash
$ sudo vim /etc/cntlm.conf 
```

Change credentials.

```
Username        USERNAME
Domain          DOMAIN-NAME
Password        PASSWORD (although quite honestly I comment out this line and generate a hash later)
```

Change the parent proxy line to only direct requests to the Squid proxy server. We are assuming Squid listens on port 3128, IPv4 address 195.168.1.51.

```
Proxy           192.168.1.51:3128
```

I also specify addresses to not pass parent proxies.

```
NoProxy         localhost, 127.0.0.*
```

Generate a cntlm password hash. This is not necessary for the current setup but it is here should you desire to implement additional accesses controls on the web-proxy.

```bash
$ sudo cntlm -H
Password: 
PassLM          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
PassNT          YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
PassNTLMv2      ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ    # Only for user 'USERNAME', domain 'DOMAIN-NAME'
```

Paste the above hash into `/etc/cntlm.conf`.

Restart `cntlm`.

```bash
$ sudo service cntlm restart
```

## Export proxy-settings to the environment

Open `/etc/bash.bashrc`.

```bash
$ sudo vim /etc/bash.bashrc
```

Add to the end.

```
export http_proxy=http://127.0.0.1:3128
export https_proxy=http://127.0.0.1:3128
export ftp_proxy=http://127.0.0.1:3128
```

---

Open `/etc/environment`.

```bash
$ sudo vim /etc/environment
```

Add to the end.

```
http_proxy=http://127.0.0.1:3128
https_proxy=http://127.0.0.1:3128
ftp_proxy=http://127.0.0.1:3128
```

---

Open `/etc/apt/apt.conf` and if the file does not exist, that is okay, because it is now created.

```bash
$ sudo vim /etc/apt/apt.conf
```

Add the following.

```
Acquire::http::Proxy "http://127.0.0.1:3128";
Acquire::https::Proxy "http://127.0.0.1:3128";
Acquire::ftp::Proxy "http://127.0.0.1:3128";
```

---

Open client firewall settings, if using ufw.

If using ufw and disallowing outbound traffic, add a ufw rule to allow connections to the Squid proxy server.

``` bash
$ sudo ufw allow out on eth0 to 192.168.1.45 port 3128
```

## Test APT client connection to Squid

Login and out of the client in order that the http_proxy setting take effect. Verify `apt-get update` works by toggling on-off the ufw firewall rules, disallowing outbound connections to the Squid proxy service.

```bash
# Deny all outgoing packets
$ sudo ufw default deny outgoing
# Get the status
$ sudo ufw status numbered
Status: active
     To                         Action      From
     --                         ------      ----
[ 1] 192.168.1.45 3128           ALLOW OUT   Anywhere on eth0 (out)
```

Delete the rule that exists to connect to Squid, in this case Rule 1.

```bash
$ sudo ufw delete 1
```

Try updating `apt` and use `ctrl-c` to break, since APT will hang.

```bash
$ sudo apt-get update
0% [Waiting for headers] [Waiting for headers]
```

Add back in the ufw rule to allow outbound connections to Squid and rerun `apt-get update`.

```bash
$ sudo ufw allow out on eth0 to 192.168.1.45 port 3128
$ sudo apt-get update
Ign http://us.archive.ubuntu.com trusty InRelease
Ign http://us.archive.ubuntu.com trusty-updates InRelease
Ign http://us.archive.ubuntu.com trusty-backports InRelease
Hit http://us.archive.ubuntu.com trusty Release.gpg
Get:1 http://us.archive.ubuntu.com trusty-updates Release.gpg [933 B]
Get:2 http://us.archive.ubuntu.com trusty-backports Release.gpg [933 B]
Hit http://us.archive.ubuntu.com trusty Release       
Get:3 http://us.archive.ubuntu.com trusty-updates Release [62.0 kB]    
...
```

Excellent.

## Test Google client connection to Squid

From the client, try connecting to google, which was not included in our default whitelists for Ubuntu.

```bash
$ w3m www.google.com
```

This returns:

```
ERROR

The requested URL could not be retrieved

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The following error was encountered while trying to retrieve the URL: http://www.google.com/

    Access Denied.

Access control configuration prevents your request from being allowed at this time. Please contact your service provider if you feel this is incorrect.

Your cache administrator is webmaster.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Generated Tue, 11 Nov 2014 05:26:53 GMT by SQUID-SERVER-NAME (squid/3.3.8)
```
