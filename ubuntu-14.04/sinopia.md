> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Private NPM Registry with Sinopia

Sinopia is a npm server installed locally. It caches public repositories published by [npmjs.org](https://www.npmjs.org/) and at the same time allows private repositories to be published locally (not sent to npmjs.org). 

Many of the examples below came from [Sinopia](https://github.com/rlidwka/sinopia) on GitHub and Dylan Smith's [instructive tutorial](https://blog.dylants.com/2014/05/10/creating-a-private-npm-registry-with-sinopia/).

My additions incorporate using Sinopia with nvm and sysvinit. For a detailed implementation of these refer to the Ubuntu 14.04 [post-install](https://github.com/jpfluger/examples) section.

## Installation

Sinopia uses [node-gyp](https://github.com/TooTallNate/node-gyp/) to cross-compile native addon modules to NodeJS. Install these baseline dependencies for node-gyp to function correctly.

```bash
$ sudo apt-get install -y python-software-properties python g++ make
```

---

List node versions currently installed.

```bash
$ sudo nvm ls

#OUTPUT
  v0.10.28
  v0.10.32
  v0.11.14
current: 	v0.10.32
```

Running the following npm command will by default use node version 0.10.32 to install Sinopia.

```bash
$ sudo npm install -g sinopia
```

---

Warning: do not install an npm module globally, such as

```bash
$ sudo nvm run 0.10.28 /usr/local/nvm/v0.10.28/lib/node_modules/npm/bin/npm-cli.js uninstall -g sinopia
```

because doing so will not create the desired global link in `/usr/bin` or `/usr/local/bin`. Rather when we run sinopia individually, we can tell nvm to run the specific node-version against it. This is what we will tell our custom SysVinit script to do as well.

---

Create where the private npm will reside.

```bash
$ mkdir ~/sinopia; cd ~/sinopia
```

Run sinopia.

```bash
$ sinopia

#OUTPUT
Config file doesn't exist, create a new one? (Y/n) 
===========================================================
 Creating a new configuration file: "./config.yaml"
 
 If you want to setup npm to work with this registry,
 run following commands:
 
 $ npm set registry http://localhost:4873/
 $ npm set always-auth true
 $ npm adduser
   Username: admin
   Password: XXXXXXXXXXXX
```

Type `ctrl-c` to force the server to stop.  Save the password on display. This is the admin password for the local Sinopia server that allows publishing rights (locally). Before we get to logging in with npm, there are tasks to first complete.

> [Dylant's blog](https://blog.dylants.com/2014/05/10/creating-a-private-npm-registry-with-sinopia/) provides more detail on what is going on here. For the background story, please read through his tutorial.

In this directory, find the `config.yaml` file.

```bash
$ ls

#OUTPUT
config.yaml
```

## Change the default url

If multiple developers need access to this repository, change the default url in `config.yaml`.

Open `config.yaml`.

```bash
$ vim ~/config.yaml
```

Find the line beginning with `listen` and edit as needed.

```bash
listen: 192.168.1.2:4873
```

If you are using Nginx to proxy sinopia, then comment in the following line with the desired url. Note that the default has `https` in the url string. I have tried publishing packages using Nginx-proxying with this line commented out and in. It must be commented in or will not work.

```bash
# if you use nginx with custom path, use this to override links
url_prefix: https://sinopia.example.com/
```

## Setup the SysVinit script

When Sinopia starts, `config.yaml` is read and because Sinopia was installed globally, we need to make certain Sinopia knows to read the `~/sinopia/config.yaml` file. The good news is that the SysVInit script automatically changes to `~/sinopia` and by default uses this folders `config.yaml` file. If `config.yaml` changes, then the Sinopia server must be restarted.

Create the Sinopia SysVInit file.

```bash
$ sudo vim /etc/init.d/sinopia
```

Copy into your editor this [template](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/sysvinit/node-app), replacing the example values with those required by Sinopia. 

```sh
### BEGIN INIT INFO
# Provides:          sinopia
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the sinopia web server
# Description:       starts sinopia using start-stop-daemon
### END INIT INFO

#Set the path env variable
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#Installed? "whereis nvm"
#Example: IF node ONLY (NO nvm) DAEMON=/usr/local/bin/node
DAEMON=/usr/local/bin/nvm

#This becomes the name of the pid and log file.
APPNAME="sinopia"
DESC="sinopia: a private npm repository"

PIDFILE="/var/run/$APPNAME.pid"
LOGFILE="/var/log/$APPNAME.log"

#Set the working directory. The command below will first "cd" into this directory before executing nvm
APPROOT="/path/to/working/directory/for/sinopia/"

#Format is "filename ARGS"
#Example: DAEMON_ARGS="server.js ADDITIONAL-ARGS-HERE"
DAEMON_ARGS="/usr/local/bin/sinopia"

#First check this was installed with "nvm ls" and if not install with "nvm install nodejs-version"
NODE_VERSION="0.10.32"

#Example: IF node ONLY (NO nvm): NODECMD="cd $APPROOT && exec $DAEMON $DAEMON_ARGS >>$LOGFILE 2>&1"
NODECMD="cd $APPROOT && exec $DAEMON run $NODE_VERSION $DAEMON_ARGS >>$LOGFILE 2>&1"

#Set the user:group id that this process will be run under
NODEUSER=node-app-ps:node-app-ps
```

Start the service.

```bash
$ sudo service sinopia start
```

Check that a process started for nvm and sinopia.

```bash
$ sudo ps aux | grep nvm

#OUTPUT
node-app-ps    1701  0.0  0.0  26760  2144 ?        S    15:40   0:00 /bin/bash /usr/local/bin/nvm run 0.10.32 /usr/local/bin/sinopia
```

Check if sinopia is listening on the expected port. Note that we do not `grep node` because nvm's target is the globally installed `sinopia`.

```bash
$ sudo netstat -ntulp | grep LISTEN | grep sinopia

#OUTPUT
tcp        0      0 127.0.0.1:4873          0.0.0.0:*               LISTEN      1732/sinopia    
```

If everything checks out, update the rc.d scripts so the script will start on boot.

```bash
$ sudo update-rc.d sinopia defaults 92
```

## Configure npm to use Sinopia

Tell npm to use the Sinopia server.

```bash
$ npm set registry "http://localhost:4873/"
```

Verify that a `.npmrc` file has been created in your home folder.

```bash
$ cat ~/.npmrc

#OUTPUT
registry=http://localhost:4873/
```

Now no matter what version of npm is run for the current user, npm will use Sinopia to manage private packages and interaction with the npm public repository.

> Be wary of running the `npm set registry` command with `sudo`. Doing so creates the same file in the same location but only the root user has read-write access.

## Using npm, login to Sinopia

Let's use npm to login to Sinopia. Use the password saved above.

```bash
npm login
Username: admin
Password: 
Email: (this IS public) your-email@example.com
```

After you finish, the `.npmrc` file gets updated with additional properties.

## Sinopia private repositories

Edit `config.yaml`. You should already be in the sinopia directory.

```bash
$ sudo vim config.yaml
```

Add the yaml code, as appropriate to your situtation. `loc-*:` signifies that any npm package prefixed by `loc-` will be treated as a private repository. For example, `loc-myapp` or `loc-clientapp`. The section for `*` tells Sinopia that all other packages should be reconciled against `npmjs`. The `allow_publish` command is set to `none`, which will help control accidental publishing.

```yaml
'loc-*':
	# allow all users to read packages ('all' is a keyword)
	# this includes non-authenticated users
	allow_access: all

	# allow 'admin' to publish packages
	allow_publish: admin

	# no proxies, all request should be internal only

'*':
	# allow all users to read packages (including non-authenticated users)
	#
	# you can specify usernames/groupnames (depending on your auth plugin)
	# and three keywords: "$all", "$anonymous", "$authenticated"
	allow_access: $all

	# allow 'admin' to publish packages
	allow_publish: none

	# if package is not available locally, proxy requests to 'npmjs' registry
	proxy: npmjs
```

## package.json 

In the module to be published privately, add this to `package.json`.

```vim
"publishConfig" : "http://127.0.0.1:4873",
```

As Dylant's [says](https://blog.dylants.com/2014/05/10/creating-a-private-npm-registry-with-sinopia/), "This forces users who issue a npm publish command to publish to your Sinopia server rather than the external registry.npmjs.org."

## Publishing modules

Because we are running npm using nvm, it is required to publish npm modules with sudo.

```bash
$ cd /directory/of/npm/module
$ sudo npm publish
```

## Logs

SysVinit outputs Sinopia logs to `/var/log`. 

```bash
$ cat /var/log/sinopia.log | less
```

## Notes

Debug as I might, I have one annoying "warning" that I have not been able to get rid of. When restarting Sinopia via the service command, I get the following output:

```bash
$ sudo service sinopia restart

#OUTPUT
Restarting sinopia: a private npm repository pid=/var/run/sinopia.pid 
start-stop-daemon: warning: failed to kill 28251: No such process
```

When I check which nvm-sinopia process ids and ports are open for listening, I find sinopia successfully restarts. I've tried a few techniques to get rid of this warning but have not been successful. Perhaps in the move to systemd, this will be easier to resolve.
