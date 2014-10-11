> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Using nvm for node package management

[SysVinit](https://wiki.archlinux.org/index.php/SysVinit) is the first process executed and as such is the parent of all processes. SysVinit scripts are found in the /etc/init.d directory on debian-based systems. Maybe the following command is familiar to you?

```bash
sudo service apache2 restart
```

We'll write our own SysVinit script to run on Ubuntu 14.04 using nvm. But note that mainline linux distributions are moving towards systemd and sysvinit is becoming obsoleted. When this setup moves beyond Ubuntu 14.04, I will update these examples with a [migrate to systemd](https://wiki.archlinux.org/index.php/SysVinit#Migration_to_systemd) example (such as [found here](http://java.dzone.com/articles/nodejs-production)).

This example assumes installation of [nvm-global](https://github.com/xtuple/nvm) following the [prior example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nvm-for-node-package-management.md).

## Preparing a new sysvinit script

Create a new sysvinit script file in `/etc/init.d`. The file needs root ownership and executable permissions.

```bash
sudo touch /etc/init.d/node-app
sudo chmod a+x /etc/init.d/node-app
```

Update the system service definitions. Note the number at the end of the command. A low number gets run first. I usually set my node apps with higher run-levels because of a time I could not get one program to run with the default `20`. 

```bash
sudo update-rc.d node-app defaults 92
```

Open the file in an editor.

```bash
sudo vim /etc/init.d/node-app
```

And edit this [template](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/sysvinit/node-app), replacing the example values with your own. 

## Required variables to edit

* APPNAME: This should be recognizable, perhaps the same name as the sysvinit script. It also becomes the name of the pidfile and logfile.
* DESC: Can be more detailed than APPNAME. Used in messages.
* APPROOT: The working directory. The daemon execution command will first `cd` into this directory before executing nvm
* DAEMON_ARGS: The target javascript file that node should run against first, followed by any arguments. (eg server.js --port 8080)
* NODE_VERSION: The version of node that the daemon should use. First check that this has been installed with `sudo nvm ls` and if not install with `sudo nvm install VERSION`
* NODEUSER: The user:group that the daemon process should be run as. See the section below for help.

## Running as a secluded user

Did you see the variable `NODEUSER`? This refers to the user:group that the daemon process should be run as. You could run the process as `root:root` but this is unsafe should a vulnerability allow an attacker to gain control of the application and suddenly have `root` permissions. You could run the process with your own userid but most likely you'll have other files that you want protected in case the worst happens. You should run production node in its own unprivileged user account.

We will tell our node-app to run using both an userid and groupid named `node-app-ps`. 

Does this groupid exist?

```bash
getent group | cut -d: -f1 | grep node-app-ps
```

Does this userid exist?

```bash
awk -F':' '{ print $1}' /etc/passwd | grep node-app-ps
```

If these did not return values, then create the new `node-app-ps` user and group. This `useradd` command creates both.


```bash
sudo useradd -s /bin/bash -m -d /home/node-app-ps -c "safe node app process" node-app-ps
```

Create a password for the user. (Enter twice)

```bash
sudo passwd node-app-ps
```

Add the user to the sudo group. The user can execute root commands but only with a password.

```bash
sudo usermod -aG sudo node-app-ps
```

Within the new home directory, I create a `prod` folder. Run these commands by ssh'ing into the server or running as the user via sudo.

```bash
# sudo
sudo node-app-ps
mkdir ~/prod

# ssh
ssh node-app-ps@svr1.example.com
mkdir ~/prod
```

The `prod` folder contains the source code (eg server.js). Each username created is unique for each production node application that has its own sysvinit script. The app's user credentials are used to scp files to the production server from source control or are obtained via git clone by the admin on the server. 

## Ownership of the production directory

Who should the user:group owner be of the `prod` directory?  The user is `node-app-ps` and the group is `node-app-ps`. But is that correct?  Shouldn't I do something more with `chmod` or `chown` to harden my system?

> Note: Some file ownership strategies can be found at [Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-use-pm2-to-setup-a-node-js-production-environment-on-an-ubuntu-vps), examples from [Securing Apache](http://www.thegeekstuff.com/2011/03/apache-hardening/) and [Ruby on Apache](http://stackoverflow.com/questions/6037286/what-permissions-are-needed-for-apache-passenger), and [nvm sudo errors](http://stackoverflow.com/questions/16151018/npm-throws-error-without-sudo).

For my node-apps, I use Digital Ocean's model of creating a `safeuser` and running the node-process under that user. If the site were breached, the user would not be able to manipulate files outside of the production directory. Individual folders within the production directory could have different ownership or read-write permissions, such as making all files readable but only certain folders writable. Going to greater lengths to harden the file structure is done on a case-by-case basis. 

## Testing

Start the server. 

```bash
sudo service node-app start
```

View the process. `node` is the uid.

```bash
$ sudo ps aux | grep nvm

# OUTPUT
UID              PID
node-app-ps     13256  0.0  0.0  26760  2140 ?        S    17:31   0:00 /bin/bash /usr/local/bin/nvm run 0.10.32 server.js
node-app-ps     13287  0.0  0.0 658912 11520 ?        Sl   17:31   0:00 /usr/local/nvm/v0.10.32/bin/node server.js
```

And let's look at the process tree.

```bash
$ sudo pstree -p 13256

# OUTPUT
nvm(13256)───node(13287)───{node}(13288)
```

View by ip:port.

```bash
sudo netstat -ntulp | grep LISTEN | grep node

# OUTPUT
tcp        0      0 127.0.0.1:1337          0.0.0.0:*               LISTEN      13287/node
```

So far so good. Let's stop the server.

```bash
sudo service node-app stop
```

View the process.

```bash
$ sudo ps aux | grep nvm

# OUTPUT
(NOTHING)
```

Excellent. It works fine, though I will follow-up with a last section of what I am watching with this script.

## What I'm watching

The script works fine. I have not had issues. However, in my script, I send the TERM signal to children (node) of the parent pid (nvm). If I didn't, these children would continue to run. Also the built-in sysvinit function `start-stop-daemon` does not seem to work for the child processes but `pkill` does. I'm mentioning this because if you do run into an issue where you think the process should have stopped but it appears to be running, then this is the culprit. This is how to identify and fix it.

Find the nvm processes running.

```bash
$ sudo ps aux | grep nvm

# OUTPUT - orphaned process. Remember that in the example above there were two records returned!
UID              PID
node-app-ps     13287  0.0  0.0 658912 11520 ?        Sl   17:31   0:00 /usr/local/nvm/v0.10.32/bin/node server.js
```

Kill the specific process

```bash
sudo kill -TERM 13287
```

View the process.

```bash
$ sudo ps aux | grep nvm

# OUTPUT
(NOTHING)
```

Good results. The process has completely ended.