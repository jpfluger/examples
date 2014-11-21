> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Using nvm for Node Package Management

The production server is required to run node. But what if a new version of node comes out? What is the best way to manage the upgrade or downgrade process?  Especially on a production server?

This example on nvm and the next few examples (nginx, sysvinit and monit) cover how I use node in a production environment. 

If you followed the [prior example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/changing-hostname.md), the server has been setup with a fully-qualified-domain-name and presumably is registered in DNS. 

[nvm](https://github.com/creationix/nvm) is the primary repository for nvm but I am using a fork called [nvm-global](https://github.com/xtuple/nvm), which installs nvm globally. 

## Install nvm

Before we install nvm-global, nvm is dependent on a few additional packages. Let's install those now.

```bash
$ sudo apt-get install build-essential openssl libssl-dev git python
```

Install nvm-global.

```bash
wget -qO- https://raw.githubusercontent.com/xtuple/nvm/master/install.sh | sudo bash
```

## Use nvm

List node versions currently installed.

```bash
$ sudo nvm ls
```

List available node versions. Current production is the 0.10.* branch.

```bash
$ sudo nvm ls-remote | less
```

Install a node version. (nvm auto-switches to the new version)

```bash
$ sudo nvm install 0.10.32
```

Use a node version. This is saved, even during restarts.

```bash
$ sudo nvm use 0.10.32
```

View versions of node and node package manager (npm)

```bash
$ sudo node -v
$ sudo npm -v
```

## Putting it together

In one command, run a targeted version of node. Test this using [server.js](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/node/server.js), which is found in the examples/ubuntu-14.04/node folder. Run this command in the same directory as server.js or pass in the full path to server.js. 

```bash
# run from within the same directory as server.js
$ nvm run 0.10.32 server.js

# or pass in the full path
$ nvm run 0.10.32 /path/to/directory/server.js

# or change to the directory first and then execute the command. This is what we do in the sysvinit example.
$ cd /path/to/directory/ && exec nvm run 0.10.32 server.js
```

View the process.

```bash
$ sudo ps aux | grep nvm

# OUTPUT
svr1    5080  0.0  0.0  18340  1992 pts/31   S+   16:26   0:00 /bin/bash /usr/local/bin/nvm run 0.10.32 server.js
svr1    5111  1.0  0.0 658916 11548 pts/31   Sl+  16:26   0:00 /usr/local/nvm/v0.10.32/bin/node server.js
```

Why are there two lines? nvm is the parent process and node is the child process.

```bash
$ sudo pstree -p 5080

# OUTPUT
nvm(5080)───node(5111)───{node}(5112)
```

And why are there three process ids?  nvm(5080) is for nvm. node(5111) is for the node instance and is the value of nodejs's master process.pid. {node}(5112) represents a worker thread used internally by node. You can safely ignore this for our purposes.

End the process on the command-line by tapping `ctrl-c`. This means to end the process will stop all the child processes. Later, when we look at how sysvinit stops and starts daemons, we'll find we have to do something special to kill the child-process (eg node(5111) above).
