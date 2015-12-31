> Back to [Table of Contents](https://github.com/jpfluger/examples)

# nvm

This guide installs [Node Version Manager](https://github.com/creationix/nvm) (aka `nvm`).

## Prerequisites

Install `git`, `python` for node-based custom-bindings, and a couple database clients (`postgres` and `mysql`).

```bash
$ sudo apt-get install lsb-release libssl-dev build-essential python-all rlwrap curl git imagemagick postgresql-client mysql-client
```

Configure `git`.

```bash
$ git config --global user.name "Your Name"
$ git config --global user.email "youremail@domain.com"
```

Intall `nvm` using `git`.

```bash
$ git clone https://github.com/creationix/nvm.git ~/.nvm && cd ~/.nvm && git checkout `git describe --abbrev=0 --tags`
```

Open `.bashrc`.

```bash
$ vim ~/.bashrc
```

Add the following at the bottom. The first sources the `nvm` environment variables upon login (NVM_RC, NVM_DIR, NVM_NODEJS_ORG_MIRROR, NVM_IOJS_ORG_MIRROR) and the `alias sudo` command is the path to the current `NVM_BIN` value. This is sometimes needed, especially when installing packages globally. 

```vim
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

alias sudo='sudo env PATH=$PATH:$NVM_BIN'
```

> Note: The `alias sudo` command is from [gagle](https://github.com/gagle) at the end of [issue 43](https://github.com/creationix/nvm/issues/43).

Create a `.nvmrc` file with a default version in it. You also need to install a node version. 

```bash
# sources the nvm file. ignore if you've already logged out or rebooted b/c doing so invokes .bashrc, which sources the file as well
$ . ~/.nvm/nvm.sh
# install the latest stable version of node
$ nvm install stable 
# create the .nvmrc file
$ echo "v5.3.0" >> ~/.nvmrc
```

Logout and back in. Running both `node --version` as a regular user and sudo should return a version number.

```bash
$ node --version
v5.3.0
$ sudo node --version
v5.3.0
```


https://docs.docker.com/engine/reference/builder/

https://hub.docker.com/r/clkao/postgres-plv8/~/dockerfile/
https://hub.docker.com/r/joshfinnie/nvm/~/dockerfile/
https://hub.docker.com/r/livingdocs/nvm/~/dockerfile/
https://hub.docker.com/r/homme/openstreetmap-tiles/
https://github.com/phusion/baseimage-docker
https://hub.docker.com/r/livingdocs/postgres/
https://github.com/nodejs/docker-node