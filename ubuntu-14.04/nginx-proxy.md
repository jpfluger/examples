> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Nginx as Proxy

## Installation

Install a proxy server front-end and we can point the proxy to the desired background node process. 

```bash
$ sudo apt-get install nginx
```

## Modify nginx.conf

Open the default nginx configuration file.

```bash
$ sudo vim /etc/nginx/nginx.conf
```

Compare to the [nginx.conf](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx/nginx.conf) posted in my examples. I tweaked the `Logging Settings` entry. 

```nginx
##
# Logging Settings
##

access_log /var/log/nginx/access.log;
error_log /var/log/nginx/error.log;

log_format  main    '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $bytes_sent '
                    '"$http_referer" "$http_user_agent" "$http_x_forwarded_for" '
                    '"$gzip_ratio"';

##
# Gzip Settings
##
```

Modify other default nginx settings, as appropriate to your needs.

## Configuring a new proxying website

On your DNS server, create a DNS entry for myapp.example.com and point that name to the svr1.example.com ip address (192.168.1.2). 

Create an nginx configuration file for the `myapp` proxying website.

```bash
$ sudo vim /etc/nginx/sites-available/myapp.example.com
```

Use this [config file](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx/myapp) as your initial template.  Change the config file to point to the ip:port of the node instance that is running.

## Simplify nginx administration

Create a new script file.

```bash
$ sudo vim /usr/bin/nginx_modsite
```

Add the content from Michael Lustfield's [script](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx/nginx_modsite.sh). This script simplifies nginx administration. The script was made possible by [Michael Lustfield](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx/nginx_modsite.sh) and [Ghassen Telmoudi](http://serverfault.com/questions/424452/nginx-enable-site-command).

Make the script executable.

```bash
$ sudo chmod +x /usr/bin/nginx_modsite
```

## Script commands

List all the sites.

```bash
$ sudo nginx_modsite -l
```

Enable site `myapp`.

```bash
$ sudo nginx_modsite -e myapp
```

Disable site `myapp`.

```bash
$ sudo nginx_modsite -d myapp
```

## Test

Enable site `myapp`.

```bash
$ sudo nginx_modsite -e myapp
```

Make certain your node app is running according to [Start/Stop the node server using nvm and sysvinit](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/sysvinit-and-nvm.md).

Start the server. 

```bash
$ sudo service node-app start
```

View by ip:port.

```bash
$ sudo netstat -ntulp | grep LISTEN | grep node

# OUTPUT
tcp        0      0 127.0.0.1:1337          0.0.0.0:*               LISTEN      13287/node
```

My server is running on ip 127.0.0.1, port 1337. This is what I want. If the results were unexpected, then go back and check your sysvinit setup.

Open a browser and type in the nginx site address.

```
http://myapp.example.com
```

The node process should respond to your browser with a `Hello World` greeting.

![Results of myapp in browser](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx/myapp-hello-world.png)
