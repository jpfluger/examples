> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Docker

This setup guide is based on [Docker's Ubuntu Instructions](https://docs.docker.com/engine/installation/ubuntulinux/) and the bit dated [Digital Oceans's](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-getting-started) tutorial.

## Prerequesites

Docker runs on a 64-bit installation of any Linux distribution, including Ubuntu and requires a kernel that is at minimum version `3.10`.

```bash
$ uname -r
```

Check [Docker's Ubuntu installation](https://docs.docker.com/engine/installation/ubuntulinux/) page for the latest `gpg` key and repository.

> Note: If upgrading from a version prior than `1.7.1`, see the [installation directions](https://docs.docker.com/engine/installation/ubuntulinux/) for purging older directories.

The following is to gain access to version greater than Docker 1.7.1. (so far)

```bash
$ sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
```

Add docker to `apt` sources.

```bash
$ sudo vim /etc/apt/sources.list.d/docker.list
```

```vim
deb https://apt.dockerproject.org/repo ubuntu-trusty main
```

Save. 

Now update `apt`.

```bash
$ sudo apt-get update
```

Verify `apt` pulls from the correct repository.

```bash
$ sudo apt-cache policy docker-engine
```

Also add the `linux-image-extra` kernel package which is used by `aufs` storage driver.

```bash
$ sudo apt-get install linux-image-extra-$(uname -r)
```

## Install Docker

Install.

```bash
$ sudo apt-get install docker-engine
```

> Note: before starting Docker, you may desire to [change the installation directory](https://forums.docker.com/t/how-do-i-change-the-docker-image-installation-directory/1169).

Start Docker, which should already be running.

```bash
$ sudo service docker start
```

Test the installation.

```bash
$ sudo docker run hello-world
```

## Additional configurations

See the Docker installation instructions for [additional configurations](https://docs.docker.com/engine/installation/ubuntulinux/).

### UFW

It might be that Ubuntu's default firewall settings may need to be tweaked to `ACCEPT` forwarding of packets by default.

Edit the default `ufw` file.

```bash
$ sudo vim /etc/default/ufw
```

Change `DEFAULT_FORWARD_POLICY="DROP"` to:

```vim
DEFAULT_FORWARD_POLICY="ACCEPT"
```

Reload or restart ufw.

```bash
$ sudo ufw reload
# OR
$ sudo ufw disable
$ sudo ufw enable
```

### Memory management and reporting

This StackOverflow [response](http://stackoverflow.com/questions/28838809/docker-warning-on-cgroup-swap-limit-memory-use-hierarchy), details when you may want to enable memory management.

To enable memory and swap, edit `grub`.

```bash
$ sudo vim /etc/default/grub
```

Add to `GRUB_CMDLINE_LINUX`.

```vim
GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"
```

Update `grub`.

```bash
$ sudo update-grub
```

Reboot.

## Command overview

List available commands by using command `sudo docker`.

```bash
$ sudo docker
Usage: docker [OPTIONS] COMMAND [arg...]
       docker daemon [ --help | ... ]
       docker [ --help | -v | --version ]

A self-sufficient runtime for containers.

Options:

  --config=~/.docker                 Location of client config files
  -D, --debug=false                  Enable debug mode
  --disable-legacy-registry=false    Do not contact legacy registries
  -H, --host=[]                      Daemon socket(s) to connect to
  -h, --help=false                   Print usage
  -l, --log-level=info               Set the logging level
  --tls=false                        Use TLS; implied by --tlsverify
  --tlscacert=~/.docker/ca.pem       Trust certs signed only by this CA
  --tlscert=~/.docker/cert.pem       Path to TLS certificate file
  --tlskey=~/.docker/key.pem         Path to TLS key file
  --tlsverify=false                  Use TLS and verify the remote
  -v, --version=false                Print version information and quit

Commands:
    attach    Attach to a running container
    build     Build an image from a Dockerfile
    commit    Create a new image from a container's changes
    cp        Copy files/folders between a container and the local filesystem
    create    Create a new container
    diff      Inspect changes on a container's filesystem
    events    Get real time events from the server
    exec      Run a command in a running container
    export    Export a container's filesystem as a tar archive
    history   Show the history of an image
    images    List images
    import    Import the contents from a tarball to create a filesystem image
    info      Display system-wide information
    inspect   Return low-level information on a container or image
    kill      Kill a running container
    load      Load an image from a tar archive or STDIN
    login     Register or log in to a Docker registry
    logout    Log out from a Docker registry
    logs      Fetch the logs of a container
    network   Manage Docker networks
    pause     Pause all processes within a container
    port      List port mappings or a specific mapping for the CONTAINER
    ps        List containers
    pull      Pull an image or a repository from a registry
    push      Push an image or a repository to a registry
    rename    Rename a container
    restart   Restart a container
    rm        Remove one or more containers
    rmi       Remove one or more images
    run       Run a command in a new container
    save      Save an image(s) to a tar archive
    search    Search the Docker Hub for images
    start     Start one or more stopped containers
    stats     Display a live stream of container(s) resource usage statistics
    stop      Stop a running container
    tag       Tag an image into a repository
    top       Display the running processes of a container
    unpause   Unpause all processes within a container
    version   Show the Docker version information
    volume    Manage Docker volumes
    wait      Block until a container stops, then print its exit code

Run 'docker COMMAND --help' for more information on a command.
```

For system-wide information:

```bash
Containers: 1
Images: 2
Server Version: 1.9.1
Storage Driver: aufs
 Root Dir: /var/lib/docker/aufs
 Backing Filesystem: extfs
 Dirs: 4
 Dirperm1 Supported: false
Execution Driver: native-0.2
Logging Driver: json-file
Kernel Version: 3.13.0-71-generic
Operating System: Ubuntu 14.04.3 LTS
CPUs: 8
Total Memory: 31.37 GiB
Name: HOSTNAME
ID: XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX
WARNING: No swap limit support
WARNING: bridge-nf-call-iptables is disabled
WARNING: bridge-nf-call-ip6tables is disabled
```

And for version information:

```bash
[nezzie:Downloads]$ sudo docker version
Client:
 Version:      1.9.1
 API version:  1.21
 Go version:   go1.4.2
 Git commit:   a34a1d5
 Built:        Fri Nov 20 13:12:04 UTC 2015
 OS/Arch:      linux/amd64

Server:
 Version:      1.9.1
 API version:  1.21
 Go version:   go1.4.2
 Git commit:   a34a1d5
 Built:        Fri Nov 20 13:12:04 UTC 2015
 OS/Arch:      linux/amd64
```

## Containers

List **running** containers.

```bash
$ sudo docker ps
```

List the latest created container.

```bash
$ sudo docker ps -l
```

Show all containers.

```bash
$ sudo docker ps -a
```

### Run a container

Per the [Docker help](https://docs.docker.com/engine/userguide/dockerizing/), launch a container by specifying the `image_name` and then the command.

```bash
# Usage: sudo docker run [image name] [command to run]
$ docker run ubuntu:14.04 /bin/echo 'Hello world'
```

So long as the command is **active**, the container will run otherwise the process exits.

### Interactive containers

In order to get a command-line inside the container, we use `run` with the `-t` (assigns a terminal inside the container) and `-i` (interfactive-mode). The `/bin/bash` parameter launches Bash inside the container.

```bash
 $ sudo docker run -t -i ubuntu:14.04 /bin/bash
 root@999999999999:/# 
 ```

Type `exit` or `Ctrl-D` to leave the container. Upon exiting, the container stops.

### Run as a daemon

The `-d` parameter instructs Docker to run the container in the background as a daemon.

```bash
$ sudo docker run -d ubuntu:14.04 /bin/sh -c "while true; do echo hello world; sleep 1; done"
22deaa5047609a57e5ef6d383101bc25b2f77dfb94b1062cc93a79eb9278b97e
```

The container ID is the string returned (`22deaa5047609a57e5ef6d383101bc25b2f77dfb94b1062cc93a79eb9278b97e`). 

### View running containers

```bash
$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
22deaa504760        ubuntu:14.04        "/bin/sh -c 'while tr"   2 minutes ago       Up 2 minutes                            stoic_albattani
```

See the `name` field in the last column? Use the name instead of the ID to reference specific processes.

```bash
$ sudo docker logs stoic_albattani
```

> Note: `docker logs` returns standard output from the target container.

### Reconnect to a running container

```bash
$ sudo docker exec -it stoic_albattani bash
```

### Stop a running container

```bash
$ sudo docker stop stoic_albattani
```

Verify no containers are running.

```bash
$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

## Containers as applications

### Run a web application

The following web application runs with Python Flask. The `-P` parameters instructs Docker to map network ports from the host to the container. The `training/webapp` image is pre-built and downloaded, if not already installed.

```bash
$ sudo docker run -d -P training/webapp python app.py
```

Verify it is running.

```bash
$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                     NAMES
3b22a45f373b        training/webapp     "python app.py"     2 minutes ago       Up 2 minutes        0.0.0.0:32768->5000/tcp   naughty_bose
```

Notice the `PORTS` field, which shows the network mapping between host and container.

```
0.0.0.0:32768->5000/tcp
```

In a web browser, view the url `http://localhost:32768/`.

Any host IP (identified by `0.0.0.0`) port `32,768` gets mapped to the container's port `5000` via tcp. Alternately, specify exact port mappings using a small `p` parameter. For example, `-p 80:5000` would map port `80` on the host to port `5000` within the container. 

The full command would appear as follows.

```bash
$ sudo docker run -d -p 80:5000 training/webapp python app.py
```

### Viewing ports

A shortcut to view a running application's port number is

```bash
$ sudo docker port naughty_bose 5000
0.0.0.0:32768
```

### Viewing application logs

View logs with a tail command, `-f`.

```bash
$ sudo docker logs -f naughty_bose
 * Running on http://0.0.0.0:5000/ (Press CTRL+C to quit)
172.17.0.1 - - [11/Dec/2015 23:21:28] "GET / HTTP/1.1" 200 -
172.17.0.1 - - [11/Dec/2015 23:21:29] "GET /favicon.ico HTTP/1.1" 404 -
```

### Processes inside the container

View processes via `top`.

```bash
$ sudo docker top naughty_bose
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
root                12137               23657               0                   17:16               ?                   00:00:00            python app.py
```

In this case, the container has only one running process.

### Container status

The `inspect` command returns a JJSON document with configuration and status inormation.

```bash
$ sudo docker inspect naughty_bose
[
{
    "Id": "3b22a45f373b301b65cf538ed4a63c3271e6abf79a15b239387f262289f1d94a",
    "Created": "2015-12-11T23:16:35.935376775Z",
    "Path": "python",
    "Args": [
        "app.py"
    ],
    "State": {
        "Status": "running",
        "Running": true,
        "Paused": false,
        "Restarting": false,
[MORE]
```

Filter for values of particular properties.

```bash
$ sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' naughty_bose
172.17.0.2
```

### Stop and restart the container

Stop the container first.

```bash
$ sudo docker stop naughty_bose
naughty_bose
```

`docker ps` shows that the container `Exited`.

```bash
$ sudo docker ps -l
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                        PORTS               NAMES
3b22a45f373b        training/webapp     "python app.py"     22 minutes ago      Exited (137) 31 seconds ago                       naughty_bose
```

Restart the container.

```bash
$ sudo docker restart naughty_bose
naughty_bose
```

And verify.

```bash
$ sudo docker ps -l
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                     NAMES
3b22a45f373b        training/webapp     "python app.py"     24 minutes ago      Up 2 seconds        0.0.0.0:32769->5000/tcp   naughty_bose
```

### Other ways to restart

Other means to restart and connect to a Docker container.

Start a new interactive container.

```bash
$ sudo docker run -t -i ubuntu:14.04 /bin/bash
root@b48dd3ed5537:/# exit
```

Note the ID or name.

```bash
$ sudo docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
b48dd3ed5537        ubuntu:14.04        "/bin/bash"         14 seconds ago      Exited (0) 3 seconds ago                       angry_knuth
```

If the container has exited, then restart it so it is running.

```bash
$ sudo docker restart angry_knuth
angry_knuth
$ sudo docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED              STATUS                     PORTS               NAMES
b48dd3ed5537        ubuntu:14.04        "/bin/bash"         About a minute ago   Up 3 seconds                                   angry_knuth
```

Use the `attach` command to connect to the running process.

```bash
$ sudo docker attach angry_knuth
root@b48dd3ed5537:/# 
```

And then exit to leave again.

```bash
root@b48dd3ed5537:/# exit
exit
$ sudo docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
b48dd3ed5537        ubuntu:14.04        "/bin/bash"         2 minutes ago       Exited (0) 4 seconds ago                       angry_knuth
```

### Remove the container

Removing a container only works on stopped containers.

Is the container running?

```bash
$ sudo docker ps -l
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                      NAMES
3b22a45f373b        training/webapp     "python app.py"     24 minutes ago      Up 55 seconds        0.0.0.0:32769->5000/tcp   naughty_bose
```

Yes, so stop it.


```bash
$ sudo docker stop naughty_bose
naughty_bose
```

And remove it.

```bash
$ sudo docker rm naughty_bose
naughty_bose
```

Remove a group of them by feeding `docker rm` with a list of container IDs using `sudo docker ps -a -q

```bash
$ sudo docker rm $(sudo docker ps -a -q)
```

Stop and remove a group of containers with the following.

```bash
$ sudo docker stop $(sudo docker ps -a -q)
$ sudo docker rm $(sudo docker ps -a -q)
```

## Docker Images

Containers are built from single images.

### Search images

List available docker images. Syntax is `sudo docker search [image name]`.

```bash
$ sudo docker search ubuntu
NAME                           DESCRIPTION                                     STARS     OFFICIAL   AUTOMATED
ubuntu                         Ubuntu is a Debian-based Linux operating s...   2810      [OK]       
ubuntu-upstart                 Upstart is an event-based replacement for ...   48        [OK]       
sequenceiq/hadoop-ubuntu       An easy way to try Hadoop on Ubuntu             26                   [OK]
torusware/speedus-ubuntu       Always updated official Ubuntu docker imag...   25                   [OK]
ubuntu-debootstrap             debootstrap --variant=minbase --components...   20        [OK]       
tleyden5iwx/ubuntu-cuda        Ubuntu 14.04 with CUDA drivers pre-installed    18                   [OK]
rastasheep/ubuntu-sshd         Dockerized SSH service, built on top of of...   15                   [OK]
n3ziniuka5/ubuntu-oracle-jdk   Ubuntu with Oracle JDK. Check tags for ver...   5                    [OK]
sameersbn/ubuntu                                                               5                    [OK]
ioft/armhf-ubuntu              [ABR] Ubuntu Docker images for the ARMv7(a...   4                    [OK]
nuagebec/ubuntu                Simple always updated Ubuntu docker images...   4                    [OK]
nimmis/ubuntu                  This is a docker images different LTS vers...   3                    [OK]
maxexcloo/ubuntu               Docker base image built on Ubuntu with Sup...   2                    [OK]
seetheprogress/ubuntu          Ubuntu image provided by seetheprogress us...   1                    [OK]
isuper/base-ubuntu             This is just a small and clean base Ubuntu...   1                    [OK]
sylvainlasnier/ubuntu          Ubuntu 15.04 root docker images with commo...   1                    [OK]
densuke/ubuntu-jp-remix        Ubuntu Linuxの日本語remix風味です                       1                    [OK]
konstruktoid/ubuntu            Ubuntu base image                               0                    [OK]
tvaughan/ubuntu                https://github.com/tvaughan/docker-ubuntu       0                    [OK]
esycat/ubuntu                  Ubuntu LTS                                      0                    [OK]
rallias/ubuntu                 Ubuntu with the needful                         0                    [OK]
zoni/ubuntu                                                                    0                    [OK]
teamrock/ubuntu                TeamRock's Ubuntu image configured with AW...   0                    [OK]
birkof/ubuntu                  Ubuntu 14.04 LTS (Trusty Tahr)                  0                    [OK]
partlab/ubuntu                 Simple Ubuntu docker images.                    0                    [OK]
```

### Pulling an image

Although the `run` command automatically pulls an image, if not already present, this can be time-consuming. Images can be pre-downloaded and readied using the `pull` command.

Pull syntax is 

```bash
sudo docker pull [image name]
```

The following will pull the `latest` docker image for ubuntu.

```bash
$ sudo docker pull ubuntu
sing default tag: latest
latest: Pulling from library/ubuntu

0bf056161913: Pull complete 
1796d1c62d0c: Pull complete 
e24428725dd6: Pull complete 
89d5d8e8bafb: Pull complete 
Digest: sha256:a2b67b6107aa640044c25a03b9e06e2a2d48c95be6ac17fb1a387e75eebafd7c
Status: Downloaded newer image for ubuntu:latest
``` 

Or pull an image by `tag`, which is a better idea in a production environment.

```bash
$ sudo docker pull ubuntu:15.10
15.10: Pulling from library/ubuntu
d0fa00decafb: Pull complete 
392844978dc9: Pull complete 
a3a0dd44a4bb: Pull complete 
2804d41e7f10: Pull complete 
Digest: sha256:ae24faeb7d968197008eb7fa6970d1aa90636963947fe3486af27b079cccfb17
Status: Downloaded newer image for ubuntu:15.10
```

The Docker community has also created categories for images. Actually `category` is a misnomer. They are actually `usernames` and Docker has reserved the `training` username. An **image** belongs to the category/username. 

Pull `sinatra` from the `training` category.

```bash
$ sudo docker pull training/sinatra
Using default tag: latest
latest: Pulling from training/sinatra
d634beec75db: Pull complete 
27fb5491e391: Pull complete 
8e3415728a3f: Pull complete 
630b03963440: Pull complete 
962115fdbb58: Pull complete 
9ea38b02c228: Pull complete 
e20166048ece: Pull complete 
8b16a891bd1a: Pull complete 
Digest: sha256:03fc0cd265cbc28723e4efd446f9f2f37b4790cf9cc12f1b9203c79fb86b6772
Status: Downloaded newer image for training/sinatra:latest
```

### List images saved locally

The images on the local system are viewed with the command `sudo docker images`.

```bash
$ sudo docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ubuntu              15.10               2804d41e7f10        3 days ago          133.5 MB
ubuntu              14.04               89d5d8e8bafb        3 days ago          187.9 MB
ubuntu              latest              89d5d8e8bafb        3 days ago          187.9 MB
hello-world         latest              0a6ba66e537a        8 weeks ago         960 B
training/webapp     latest              54bb4e8718e8        7 months ago        348.8 MB
training/sinatra    latest              8b16a891bd1a        18 months ago       447 MB
```

## Changing Images

This can be done by

 1. updating an existing container (easier than #2)
 2. use `Dockerfile` (takes more doing)

### Updating an image via container (#1)

Create and run a container in interactive mode.

```bash
$ sudo docker run -t -i training/sinatra /bin/bash
root@ee6327d9f398:/# 
```

> Note: the container ID is `ee6327d9f398`.

Install something, like a ruby gem.

```bash
root@ee6327d9f398:/# gem install json
Fetching: json-1.8.3.gem (100%)
Building native extensions.  This could take a while...
Successfully installed json-1.8.3
1 gem installed
Installing ri documentation for json-1.8.3...
Installing RDoc documentation for json-1.8.3...
```

Now exit the container.

```bash
root@ee6327d9f398:/# exit
exit
```

### Commit changes

When a container is configured to the point where an image of it can be created, use the `commit` command. The `-m` parameter specifies a commit message. The `-a` parameter specifies an author. The `ouruser` is the category to which the image should belong.

```
$ sudo docker commit -m "Added json gem" -a "John Smith" ee6327d9f398 ouruser/sinatra:v2
a104335db835c62bce2ee46a515596048bb2b71bbf95f05fc57605432e211ddf
```

List the images.

```bash
$ sudo docker images
REPOSITORY          TAG                 IMAGE ID            CREATED              VIRTUAL SIZE
ouruser/sinatra     v2                  a104335db835        About a minute ago   452.3 MB
training/sinatra    latest              8b16a891bd1a        18 months ago        447 MB
```

Create a container from the new image.

```bash
$ $ sudo docker run -t -i ouruser/sinatra:v2 /bin/bash
root@8080cfef9bdb:/# exit
```

### Updating an image using Dockerile (#2)

Building an image from a Dockerfile allows for nuanced control over image builds. The `build` command builds new images from scratch.

> Note: Refer to Docker's [best practices document](https://docs.docker.com/engine/articles/dockerfile_best-practices/) for additional tips and tricks.

Create a `Dockerfile` in an isolated directory. If additional files need to be part of the build, they can be added within here.

```bash
$ mkdir sinatra
$ cd sinatra
$ touch Dockerfile
```

Open the `Dockerfile`.

```bash
$ sudo vim Dockerfile
```

Add the following.

```vim
# This is a comment
FROM ubuntu:14.04
MAINTAINER John Smith <jsmith@example.com>
RUN apt-get update && apt-get install -y ruby ruby-dev
RUN gem install sinatra
```

> Note: you may get warmings in the output from the build. The one's I had could [safely be ignored](https://github.com/docker/docker/issues/4032).

Build it. The `-t` parameter is the repository name and optionally a tag.

```bash
$ sudo docker build -t ouruser/sinatra:v2 .
Sending build context to Docker daemon 2.048 kB
Step 1 : FROM ubuntu:14.04
 ---> 89d5d8e8bafb
Step 2 : MAINTAINER John Smith <jsmith@example.com>
 ---> Running in 0d132166f125
 ---> 3229069ceaa3
Removing intermediate container 0d132166f125
Step 3 : RUN apt-get update && apt-get install -y ruby ruby-dev
 ---> Running in de57dae1058d
Ign http://archive.ubuntu.com trusty InRelease
Get:1 http://archive.ubuntu.com trusty-updates InRelease [64.4 kB]
Get:2 http://archive.ubuntu.com trusty-security InRelease [64.4 kB]
Hit http://archive.ubuntu.com trusty Release.gpg
[MORE]
```

List the images.

```bash
$ sudo docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ouruser/sinatra     v2                  6c154748b8f5        2 minutes ago       319.1 MB
ubuntu              14.04               89d5d8e8bafb        3 days ago          187.9 MB
training/sinatra    latest              8b16a891bd1a        18 months ago       447 MB
```

Create the container.

```bash
$ sudo docker run -t -i ouruser/sinatra:v2 /bin/bash
root@7899e7cf271d:/# exit
```

List the containers.

```bash
$ sudo docker ps -a
CONTAINER ID        IMAGE                COMMAND             CREATED             STATUS                          PORTS               NAMES
7899e7cf271d        ouruser/sinatra:v2   "/bin/bash"         2 minutes ago       Exited (0) About a minute ago                       amazing_bose
ee6327d9f398        training/sinatra     "/bin/bash"         48 minutes ago      Exited (1) 32 minutes ago                           thirsty_mayer
```

### Tag an image

This tags the image with an ID of `6c154748b8f5` to `devel`.

```bash
sudo docker tag 6c154748b8f5 ouruser/sinatra:devel
```

Notice it didn't create a new image because the ID is the same. But it did create a new version for that ID.

```bash
$ sudo docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ouruser/sinatra     v2                  6c154748b8f5        5 minutes ago       319.1 MB
ouruser/sinatra     devel               6c154748b8f5        5 minutes ago       319.1 MB
```

### Image digests

List digest values. My local images do not have a digest value associated with them.

```
$ sudo docker images --digests | head
REPOSITORY          TAG                 DIGEST              IMAGE ID            CREATED             VIRTUAL SIZE
ouruser/sinatra     v2                  <none>              6c154748b8f5        6 minutes ago       319.1 MB
ouruser/sinatra     devel               <none>              6c154748b8f5        6 minutes ago       319.1 MB
```

> Note: When pushing or pulling to a v2.0 Docker registry, the command output includes the image digest. If needed, `pull`using a digest value.

### Sharing images

If you want to share your Docker container with the world, push your image to the index, so anyone may use it.

First build an image file and `commit` changes.

Then `push` changes.

```bash
$ sudo docker push ouruser/sinatra
The push refers to a repository [ouruser/sinatra] (len: 1)
Sending image list
Pushing repository ouruser/sinatra (3 tags)
```

> Note: Pushing changes to the official Docker index requires you to sign-up for an account on [Docker](https://hub.docker.com/).  You may setup a private index to suit your own needs by following this [Digital Ocean tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-14-04).

### Remove an image

Remove a local image using the `rmi` command.

```bash
$ sudo docker rmi training/sinatra
```

> Note: In order to successfully remove an image, no containers must be actively based on the image.

## Networking containers

Networked containers is the process of linking containers together into a single application stack. Networks are used to isolate containers from other containers or networks.

Container names become more important when creating an application stack. When running `docker run` includes a convenient parameter `--name NAME` which replaces the auto-generated name (eg `naughty_bose`) with one you specify (eg webserver).  Container names must be unique.

```bash
$ sudo docker run -d -P --name web training/webapp python app.py
python app.py
257d9dd471b7d81bd00244864595bc7a4715c60eb7b8615a0326202a75c6ba07
```

List it.

```bash
$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                     NAMES
257d9dd471b7        training/webapp     "python app.py"     19 seconds ago      Up 18 seconds       0.0.0.0:32770->5000/tcp   web
```

Inspect it by name.

```bash
$ sudo docker inspect web
[
{
    "Id": "257d9dd471b7d81bd00244864595bc7a4715c60eb7b8615a0326202a75c6ba07",
    "Created": "2015-12-12T03:24:29.694714866Z",
    "Path": "python",
    "Args": [
        "app.py"
    ],
    "State": {
        "Status": "running",
        "Running": true,
        "Paused": false,
[MORE]
```

Stop and remove `web`.

```bash
$ sudo docker stop web && sudo docker rm web
web
web
```

### Network inspection

By default, Docker includes three networks. (seen below) The `bridge` and `overlay` driver are provided by Docker but users with advanced cases can write a plugin.

```bash
$ sudo docker network ls
NETWORK ID          NAME                DRIVER
774a5d2033c2        none                null                
b5d9d120e32d        host                host                
8edec34561b2        bridge              bridge              
```

The `bridge` driver is the default network that containers join, unless the container is instructed differently. 

Inspect the `bridge`.

```bash
$ sudo docker network inspect bridge
```

Which shows the following. **Notice** the property for `Containers` is empty because no containers are running.

```json
[
    {
        "Name": "bridge",
        "Id": "8edec34561b221fe5b49333ce5f0bf5a53f36cc09e809c2df8baf71f6f73ed3a",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {
                    "Subnet": "172.17.0.0/16"
                }
            ]
        },
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        }
    }
]
```

Launch a new container with `networktest` as its name.

```bash
$ sudo docker run -itd --name=networktest ubuntu
d32359239a93d8291a7d10900551c230b44265a9a845007217ecb3b91e04251b
```

Inspect the network properties of `bridge` now.

```bash
$ sudo docker network inspect bridge
```

Which reveals an active container.

```json
{
    "Name": "bridge",
    "Id": "8edec34561b221fe5b49333ce5f0bf5a53f36cc09e809c2df8baf71f6f73ed3a",
    "Scope": "local",
    "Driver": "bridge",
    "IPAM": {
        "Driver": "default",
        "Config": [
            {
                "Subnet": "172.17.0.0/16"
            }
        ]
    },
    "Containers": {
        "d32359239a93d8291a7d10900551c230b44265a9a845007217ecb3b91e04251b": {
            "EndpointID": "e33ff01ee4493f1d4cd3230dec55f762e4ef65c39572b3e82283daf186d08bfc",
            "MacAddress": "02:42:ac:11:00:02",
            "IPv4Address": "172.17.0.2/16",
            "IPv6Address": ""
        }
    },
    "Options": {
        "com.docker.network.bridge.default_bridge": "true",
        "com.docker.network.bridge.enable_icc": "true",
        "com.docker.network.bridge.enable_ip_masquerade": "true",
        "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
        "com.docker.network.bridge.name": "docker0",
        "com.docker.network.driver.mtu": "1500"
    }
}
```

### Network disconnect

Disconnect a network from a container by using the `network disconnect` command.

```bash
$ sudo docker network disconnect bridge networktest
```

### Create a network bridge

Create a network based on the `bridge` driver using the `-d` parameter. 

```bash
$ sudo docker network create -d bridge my-bridge-network
38afc50e9f4264efd0ce344e490f127978fa9e94c61329cb450e5b54f201551e
```

List the available networks.

```bash
$ sudo docker network ls
NETWORK ID          NAME                DRIVER
774a5d2033c2        none                null                
b5d9d120e32d        host                host                
8edec34561b2        bridge              bridge              
38afc50e9f42        my-bridge-network   bridge
```

Inspecting it reveals an empty network.

```bash
$  sudo docker network inspect my-bridge-network
[
    {
        "Name": "my-bridge-network",
        "Id": "38afc50e9f4264efd0ce344e490f127978fa9e94c61329cb450e5b54f201551e",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {}
            ]
        },
        "Containers": {},
        "Options": {}
    }
]
```

### Network isolation

Web Applications that work together securely relay on being able to communicate in the same subnetwork. 

Launch a new container running Postgresql and connect it to the new `my-bridge-network` using the `--net` parameter.

```bash
$ sudo docker run -d --net=my-bridge-network --name db training/postgres
Unable to find image 'training/postgres:latest' locally
latest: Pulling from training/postgres
00f764745b0b: Pull complete 
17fed85a94b2: Pull complete 
a3ca0a18029c: Pull complete 
d6ec4acf11f8: Pull complete 
b5309a2808e4: Pull complete 
470cb0956188: Pull complete 
7cc20b0c0d83: Pull complete 
76dc641b9b7a: Pull complete 
53672b4d013b: Pull complete 
bc14fcdc039b: Pull complete 
9c310733c3c3: Pull complete 
23ba9dda1e72: Pull complete 
82f6e5db5749: Pull complete 
Digest: sha256:a945dc6dcfbc8d009c3d972931608344b76c2870ce796da00a827bd50791907e
Status: Downloaded newer image for training/postgres:latest
ff431b96fa48350bc081778d350aca4b877c39f2511ebc712770b1df6e83877f
```

A container is now attached to `my-bridge-network`.

```bash
$ sudo docker network inspect my-bridge-network
[
    {
        "Name": "my-bridge-network",
        "Id": "38afc50e9f4264efd0ce344e490f127978fa9e94c61329cb450e5b54f201551e",
        "Scope": "local",
        "Driver": "bridge",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {}
            ]
        },
        "Containers": {
            "ff431b96fa48350bc081778d350aca4b877c39f2511ebc712770b1df6e83877f": {
                "EndpointID": "a46943e8358594dac2f025fda8d41af25d783f3b6c172686a23236d51695e2d5",
                "MacAddress": "02:42:ac:12:00:02",
                "IPv4Address": "172.18.0.2/16",
                "IPv6Address": ""
            }
        },
        "Options": {}
    }
]
```

Even the routing table shows the new network, `br-38afc50e9f42`.

```bash
$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
172.17.0.0      0.0.0.0         255.255.0.0     U         0 0          0 docker0
172.18.0.0      0.0.0.0         255.255.0.0     U         0 0          0 br-38afc50e9f42
```

And here are container's network settings. 

```bash
$ sudo docker inspect -f '{{json .NetworkSettings.Networks}}' db | python -mjson.tool
{
    "my-bridge-network": {
        "EndpointID": "a46943e8358594dac2f025fda8d41af25d783f3b6c172686a23236d51695e2d5",
        "Gateway": "172.18.0.1",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "IPAddress": "172.18.0.2",
        "IPPrefixLen": 16,
        "IPv6Gateway": "",
        "MacAddress": "02:42:ac:12:00:02"
    }
}
```

> Note: We prettify the json by passing it into python using `| python -mjson.tool`.

### Add a container to the isolated network

Start the python webapp created earlier. (Or remember the command will create a new container, if the target container is not found.)

```bash
$ sudo docker run -d --name web training/webapp python app.py
f1977377fba51768c25e00607cb6e223f2c72fe9eb6d793b2dac85e992b47e44
```

Inspect this container's network settings.

```bash
$ sudo docker inspect -f '{{json .NetworkSettings.Networks}}' web | python -mjson.tool
{
    "bridge": {
        "EndpointID": "b813c45498f9be26c564499ca6ffc6913a46b370c1df0e30ffa13e2589cd3e81",
        "Gateway": "172.17.0.1",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "IPAddress": "172.17.0.2",
        "IPPrefixLen": 16,
        "IPv6Gateway": "",
        "MacAddress": "02:42:ac:11:00:02"
    }
}
```

Notice `web` is in the `172.17.0.0` network whereas `db` is in `172.18.0.0`, so they will not be able to communicate with one another.

Verify this is true by opening a shell to the `db` container and ping `web`. The output below shows 100% packet loss for the ping.

```bash
$ sudo docker exec -it db bash
root@ff431b96fa48:/# ping 172.17.0.2
PING 172.17.0.2 (172.17.0.2) 56(84) bytes of data.
^C
--- 172.17.0.2 ping statistics ---
11 packets transmitted, 0 received, 100% packet loss, time 10080ms

root@ff431b96fa48:/# exit
```

> Note: use `Ctrl-C` to end the ping.

Attach `web` to the `db` network of `my-bridge-network`.

```bash
$ sudo docker network connect my-bridge-network web
```

Notice attaching the network added a second network to `web`.

```bash
$ sudo docker inspect -f '{{json .NetworkSettings.Networks}}' web | python -mjson.tool
{
    "bridge": {
        "EndpointID": "b813c45498f9be26c564499ca6ffc6913a46b370c1df0e30ffa13e2589cd3e81",
        "Gateway": "172.17.0.1",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "IPAddress": "172.17.0.2",
        "IPPrefixLen": 16,
        "IPv6Gateway": "",
        "MacAddress": "02:42:ac:11:00:02"
    },
    "my-bridge-network": {
        "EndpointID": "8aecbbd4d273246a640507f2459be30112296b01ed833d8ca966ccf0b7226f09",
        "Gateway": "172.18.0.1",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "IPAddress": "172.18.0.3",
        "IPPrefixLen": 16,
        "IPv6Gateway": "",
        "MacAddress": "02:42:ac:12:00:03"
    }
}
```

Try pinging `web` from within `db` now.

```bash
$ sudo docker exec -it db bash
root@ff431b96fa48:/# ping 172.18.0.3
PING 172.18.0.3 (172.18.0.3) 56(84) bytes of data.
64 bytes from 172.18.0.3: icmp_seq=1 ttl=64 time=0.126 ms
64 bytes from 172.18.0.3: icmp_seq=2 ttl=64 time=0.089 ms
64 bytes from 172.18.0.3: icmp_seq=3 ttl=64 time=0.098 ms
^C
--- 172.18.0.3 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1999ms
rtt min/avg/max/mdev = 0.089/0.104/0.126/0.017 ms
root@ff431b96fa48:/# exit
exit
```

## Data volumes

Within Docker, a `data volume` bypasses the [Union File System](https://docs.docker.com/engine/reference/glossary/#union-file-system). 

Per the [official documents](https://docs.docker.com/engine/userguide/dockervolumes/), key features include:

 * Volumes are initialized upon container creation. If the base image has mount points, the data within is copied into the new volume.
 * Containers may share and reuse data volumes.
 * A data volume's changes are made directly.
 * A data volume's changes are **not included** when an image is updated.
 * Data volumes persist, even after a container has been deleted.

> Note: This section also found this Digital Ocean [tutorial](https://www.digitalocean.com/community/tutorials/how-to-work-with-docker-data-volumes-on-ubuntu-14-04) helpful.

### Add a data volume

The `-v` parameter specifies the volume to add. 

```
$ sudo docker run -d -P --name web2 -v /webapp training/webapp python app.py
18ee5030b84f5a2878838378afa79d4c95875e248075e426cc49662127631619
```

Which creates the following entry in `web2`.

```bash
$ sudo docker inspect web2

    "Mounts": [
        {
            "Name": "a3406c7ae5f5a86a959ab6a54a92d9595f5174ee2c25660fda6551c01daf841a",
            "Source": "/ciderscratch/docker/_system/volumes/a3406c7ae5f5a86a959ab6a54a92d9595f5174ee2c25660fda6551c01daf841a/_data",
            "Destination": "/webapp",
            "Driver": "local",
            "Mode": "",
            "RW": true
        }
    ],
```

Per this StackOverflow [response](http://stackoverflow.com/questions/28302178/how-can-i-add-a-volume-to-an-existing-docker-container), add a second data volume to an existing container in the following way.

Commit the container by exitisting ID to a newly named container (eg `web4`).

```bash
$ sudo docker commit 18ee5030b84f web4
82e8470ecb89583a7ab66f96be3db47796ba21834e79df9cf2ba50c5918cb22d
```

This can be found under images.

```bash
$ sudo docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
web4                latest              82e8470ecb89        26 seconds ago      348.8 MB
```

Run a new container.

```bash
$ sudo docker run -d -P --name web4container -v /webapp2 -v /webapp3 web4 python app.py
919b4e7783847719efdbdf77ab94ef31d6c2727640d4de5441788003273aea53
```

Inspect the volumes in `web4container`.

```bash
$ sudo docker inspect web4container
    "Mounts": [
        {
            "Name": "e2f6445a66c45730596836b67f9bfe77454db491e18e30216f7eae6f7502f47d",
            "Source": "/ciderscratch/docker/_system/volumes/e2f6445a66c45730596836b67f9bfe77454db491e18e30216f7eae6f7502f47d/_data",
            "Destination": "/webapp2",
            "Driver": "local",
            "Mode": "",
            "RW": true
        },
        {
            "Name": "e54dc8e69b31ff73eaf8997a37050624ea63390acee7d44beb770872509cfa6d",
            "Source": "/ciderscratch/docker/_system/volumes/e54dc8e69b31ff73eaf8997a37050624ea63390acee7d44beb770872509cfa6d/_data",
            "Destination": "/webapp3",
            "Driver": "local",
            "Mode": "",
            "RW": true
        },
        {
            "Name": "1c2c323bff631d1f057ea7219786db2cd5559270c899a02bedc01debc64c306b",
            "Source": "/ciderscratch/docker/_system/volumes/1c2c323bff631d1f057ea7219786db2cd5559270c899a02bedc01debc64c306b/_data",
            "Destination": "/webapp",
            "Driver": "local",
            "Mode": "",
            "RW": true
        }
    ],
```

### Add a volume mapped to the host

The following command maps a Docker volume (eg `/webapp5`) to a drive on the host (eg `/ciderscratch/docker/test`).

```bash
$ sudo docker run -d -P --name web5container -v /ciderscratch/docker/test:/webapp5 training/webapp python app.py
a41848b251bdf17dfcbe285c5d00e20c4e09bf656eae33450ca4f65c35554c1b
```

Inspect the volumes in `web5container`.

```bash
$ sudo docker inspect web5container
    "Mounts": [
        {
            "Source": "/ciderscratch/docker/test",
            "Destination": "/webapp5",
            "Mode": "",
            "RW": true
        }
    ],
```

Verify the mapping. In this case, we should see a test file named `t1.txt`.

```bash
$ sudo docker exec -it web5container bash
root@a41848b251bd:/opt/webapp# ls /
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var  webapp5
root@a41848b251bd:/opt/webapp# ls /webapp5
t1.txt
root@a41848b251bd:/opt/webapp# exit
```

> Note: If the volume `/webapp5` already exists, Docker will overlay the host drive over `/webapp5` and not destroy any data. Once unmounted, original content is accessible.

### Set a docker volume as read-only

Docker volumes can be mounted in read-only mode.

```bash
$ sudo docker run -d -P --name web6container -v /ciderscratch/docker/test:/webapp6:ro training/webapp python app.py
f049cc20d4a8787e041cb918d97009ac357c3fccffde4e6e92ca1be3a9533efe
```

Inspect the volumes in `web6container`, which shows read-only (`ro`) mode.

```bash
$ sudo docker inspect web6container
    "Mounts": [
        {
            "Source": "/ciderscratch/docker/test",
            "Destination": "/webapp6",
            "Mode": "ro",
            "RW": false
        }
    ],
```

Verify file `t1.txt` is read-only by attempting to delete it (which should fail).

```bash
$ sudo docker exec -it web6container bash
root@f049cc20d4a8:/opt/webapp# ls /
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var  webapp6
root@f049cc20d4a8:/opt/webapp# ls /webapp6
t1.txt
root@f049cc20d4a8:/opt/webapp#: rm /webapp6/t1.txt 
rm: cannot remove '/webapp6/t1.txt': Read-only file system
root@f049cc20d4a8:/opt/webapp# exit
```

### Create a data volume container

Create a new named container for a data volume but do not run it. The following example reuses the image `training/postgres` to save space on adding the [layer](https://docs.docker.com/engine/introduction/understanding-docker/) for the named volume.

```bash
$ sudo docker create -v /dbdata --name dbdata training/postgres /bin/true
14b5c0bf634b103ffa3c41f83196e934a89a321fd838b16b240f58df09269474
$ sudo docker ps -l
CONTAINER ID        IMAGE               COMMAND             CREATED              STATUS              PORTS               NAMES
14b5c0bf634b        training/postgres   "/bin/true"         About a minute ago   Created                                 dbdata
```

Then use `--volumes-from` to mount the volume in a different container.

```bash
sudo docker run -d --volumes-from dbdata --name db1 training/postgres
e5d9ff8b7118051083043f10d06b64498b22c0a9db631359f5ccfca682e43d67
```

And do it a second time.

```bash
sudo docker run -d --volumes-from dbdata --name db2 training/postgres
$ c83e0f13d55c5d63932e9c7283a9b263fd91a70573ec316f2f2fcb39d29d6643
```

View the containers.

```bash
$ sudo docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
c83e0f13d55c        training/postgres   "su postgres -c '/usr"   2 minutes ago       Up 2 minutes        5432/tcp            db2
e5d9ff8b7118        training/postgres   "su postgres -c '/usr"   2 minutes ago       Up 2 minutes        5432/tcp            db1
14b5c0bf634b        training/postgres   "/bin/true"              5 minutes ago       Created   
```

> Note: From the [official documentation](https://docs.docker.com/engine/userguide/dockervolumes/), if the `postgres` image contained a directory called `/dbdata` then mounting the volumes from the `dbdata` container hides the `/dbdata` files form the `postgres` image. The result is only the files from the `dbdata` container are visible.

Extend the chain by referencing the `db1` container's volumes (which in turn came from `dbdata`) in a new container.

```bash
$ sudo docker run -d --name db3 --volumes-from db1 training/postgres
6eae4b102f05532ecca8f0510220c8672077981be5275a4bd4a69f69bd210512
```

As can be seen below, the volume references for each of the containers just created point to the same data volume.

```bash
$ sudo docker inspect -f '{{json .Mounts}}' dbdata | python -mjson.tool
[
    {
        "Destination": "/dbdata",
        "Driver": "local",
        "Mode": "",
        "Name": "652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a",
        "RW": true,
        "Source": "/ciderscratch/docker/_system/volumes/652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a/_data"
    }
]
$ sudo docker inspect -f '{{json .Mounts}}' db1 | python -mjson.tool
[
    {
        "Destination": "/dbdata",
        "Driver": "local",
        "Mode": "",
        "Name": "652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a",
        "RW": true,
        "Source": "/ciderscratch/docker/_system/volumes/652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a/_data"
    }
]
$ sudo docker inspect -f '{{json .Mounts}}' db2 | python -mjson.tool
[
    {
        "Destination": "/dbdata",
        "Driver": "local",
        "Mode": "",
        "Name": "652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a",
        "RW": true,
        "Source": "/ciderscratch/docker/_system/volumes/652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a/_data"
    }
]
$ sudo docker inspect -f '{{json .Mounts}}' db3 | python -mjson.tool
[
    {
        "Destination": "/dbdata",
        "Driver": "local",
        "Mode": "",
        "Name": "652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a",
        "RW": true,
        "Source": "/ciderscratch/docker/_system/volumes/652ef276fb1b9f394fd249977a8e9e047768a23fe8791177fd786b18c35fd64a/_data"
    }
]
```

> Note: remember that to delete a volume from disk, one must explicitly remove it via `docker rm -v VOLUME-ID` or `docker volume rm VOLUME-ID`.

### Backup, restore or migrate data volumes

Create a new container that can be run once (eg via `cron`) and pass in a command to `tar` the contents. Optionally, expand on this to add time-stamps or gzip compression. To add gzip compression, add a `z` to the tar command as in `tar zcvf`. (I created some dummy data in the `/dbdata` folder before continuing.)

```bash
$ sudo docker run --volumes-from dbdata -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /dbdata
```

Restore to the same container or a different one. Below, we create a new container with its own data volume (eg because we are not using `volumes-from`).

```bash
$ sudo docker run -v /dbdata --name dbdata2 ubuntu /bin/bash
```

Restore the backup file to the container's data volume. If the backup file was compressed with `gzip`, add a `z` to `tar` parameters to uncompress it.

```bash
$ sudo docker run --volumes-from dbdata2 -v $(pwd):/backup ubuntu bash -c "cd /dbdata && tar xvf /backup/backup.tar"
```

Let's find the path within `dbdata2` to its data volume.

```bash
$ sudo docker inspect -f '{{json .Mounts}}' dbdata2 | python -mjson.tool
[
    {
        "Destination": "/dbdata",
        "Driver": "local",
        "Mode": "",
        "Name": "eaf972e6aadeb557f41393e3ebd7d002bbb57910529b36332cbfd8710cb21541",
        "RW": true,
        "Source": "/ciderscratch/docker/_system/volumes/eaf972e6aadeb557f41393e3ebd7d002bbb57910529b36332cbfd8710cb21541/_data"
    }
]
```

View the restored `/dbdata` directory.

```bash
$ sudo ls -lh /ciderscratch/docker/_system/volumes/eaf972e6aadeb557f41393e3ebd7d002bbb57910529b36332cbfd8710cb21541/_data/dbdata
total 8.0K
-rw-r--r-- 1 root root 15 Dec 13 14:18 test2.txt
-rw-r--r-- 1 root root 12 Dec 13 14:17 test.txt
```

### Data corruption

Beware that multiple containers can share data volumes and the host can directly access data volumes. Plan for how data is to be acted upon. For example, connect to a database via ip rather than share a data volume file between databases. Doing so will corrupt the file.

## Docker Hub

See the Docker [documents](https://docs.docker.com/engine/userguide/dockerrepos/) for assistance.

