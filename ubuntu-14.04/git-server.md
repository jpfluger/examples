> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Git Server

Plenty of tutorials exist about setting up a simple git server with ssh access. Most are some variation on the [Git Pro Book's](http://git-scm.com/book/en/v2) chapter on [Setting Up the Server](http://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server).

## Create a user

Create a new user who will access this git server. Although we are creating a new Linux user, conceptually think of this single user-account being acccessed by multiple users. Each will have provided his or her public RSA key, so that SSH permits access from them. In the section after this one, we'll swap-out the default user login shell for "git-shell".

```bash
$ sudo adduser git
Adding user `git' ...
Adding new group `git' (1002) ...
Adding new user `git' (1002) with group `git' ...
Creating home directory `/home/git' ...
Copying files from `/etc/skel' ...
Enter new UNIX password: 
Retype new UNIX password: 
passwd: password updated successfully
Changing the user information for git
Enter the new value, or press ENTER for the default
	Full Name []: 
	Room Number []: 
	Work Phone []: 
	Home Phone []: 
	Other []: 
Is the information correct? [Y/n] (Y)
```

## SSH Keys

Use `su` to login as the new user. 

```bash
$ su git
$ cd
```

Create the directory for ssh and the authorized keys it holds.

```bash
$ mkdir .ssh && chmod 700 .ssh
$ touch .ssh/authorized_keys && chmod 600 .ssh/authorized_keys
```

Exit the `git` user terminal.

```bash
$ exit
```

## Add git-shell as a login option

If we do not want the newly created user to have full access over ssh, then set the user's first shell to "git-shell", which then restricts the user to git-related commands only.

> Note: Don't run this section before the others or else you'll need to switch login shells to complete commands.

Does the server know where the git-shell script resides? (Yes)

```bash
$ which git-shell
/usr/bin/git-shell
```

Is this shell already considered valid by the operating system? (No)

```bash
$ cat /etc/shells
# /etc/shells: valid login shells
/bin/sh
/bin/dash
/bin/bash
/bin/rbash
/bin/ksh93
```

Since git-shell is not listed, we need to add it. Open for editing.

```bash
$ sudo vim /etc/shells
```

Append to the end.

```
/usr/bin/git-shell
```

Save.

---

Assign `git` to use git-shell.

```bash
$ sudo chsh git -s /usr/bin/git-shell
```

Verify.

```bash
$ cat /etc/passwd | grep git
git:x:1001:1001:,,,:/home/git:/usr/bin/git-shell
```

## SSH Keys: Create New

Back in a terminal logged in as myself, let's create an RSA key pair which we can test with.

```bash
$ cd ~/.ssh
$ ssh-keygen -C "john@example.com"
Generating public/private rsa key pair.
Enter file in which to save the key (/home/USER/.ssh/id_rsa): id_rsa_john
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in id_rsa_john.
Your public key has been saved in id_rsa_john.pub.
The key fingerprint is:
a0:82:28:c2:ec:40:3d:7c:d7:79:77:bb:f2:37:18:60 john@example.com
The key's randomart image is:
+--[ RSA 2048]----+
|                 |
|  o     . .      |
| . + ... o . . . |
|=.  o...  .E. . .|
|*o. .   S . .  . |
|=  .         .  .|
| .           .o. |
|             .o..|
|               .o|
+-----------------+
```

```
$ ls -l *john*
-rw------- 1 USER GROUP 1766 Dec 19 00:22 id_rsa_john
-rw-r--r-- 1 USER GROUP  398 Dec 19 00:22 id_rsa_john.pub
```

## SSH Keys: Initialize in 'git' user

The public key of `john` looks like this:

```
$ cat id_rsa_john.pub 
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSskN51MQDe3+CAQ8X5dt4KApqLd6PhDOfDBHqUMTUSpFBzZZyC81j6kS2wX77EiW99rK7g0fULb4ZpZP45ryV8+X+IZcMLVxK8Z89t4uTvzRE4VJZmXoUehmkIGkRCwWuD8gLGEEhGHXtYxNRb92PNozv0+6IZoxjwEhT58a14S4OeSemDuWD9G17aXyRkunkQvfNG42QdW5tkGZbDtJQ4lb3Yocx8FOImtdYGnF6VvGb1ddivl06hK3Smxh/0RkYXqaliw4ABBc8Rx4qyaCCqTjUYrDZAAIDRH+9mM7vPZF24zk9CEILJX6Z1o1icHOABkglbrGtYDNdY9uz/g6r john@example.com
```

Copy the public key of `john` into the `authorized_keys` file of the git user we created.

Open the authorized_keys files in a text editor.

```bash
$ sudo vim /home/git/.ssh/authorized_keys
```

Paste in John's public key and save. 

> Note: This command will error: `sudo cat id_rsa_john.pub >> /home/git/.ssh/authorized_keys`

## Create Git Repository

Create a directory for git repositories in the options folder.

```bash
$ sudo mkdir /opt/git
```

Or, if the git directory resides in a different location, create a symbolic link to it from the options directory.

```bash
$ sudo ln -s /path/to/git/repos /opt/git
```

Change into the git directory and initialize the first repository, which we'll call test.

```bash
$ cd /opt/git
$ git init --bare test.git
Initialized empty Git repository in /path/to/git/repos/test.git/
```

Change the permissions to that of the `git` user.

```bash
$ sudo chown git:git -R test.git
```

## Access from Ubuntu Client

A few ways to get started, now that a bare repo has been created on the git server. All actions happen on John's Ubuntu work station.

Method One: clone the uninitialized bare repository, do some work and then push back changes.

```bash
$ git clone git@FQDN:/opt/git/test.git 
Cloning into 'test'...
warning: You appear to have cloned an empty repository.
Checking connectivity... done.
$ cd test
$ echo "wow" >> file.txt
$ git add .
$ git commit -m 'initial commit from john'
[master (root-commit) 3c45fa8] initial commit from john
 1 file changed, 1 insertion(+)
 create mode 100644 file.txt
$ git push origin master
Counting objects: 3, done.
Writing objects: 100% (3/3), 226 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To git@FQDN:/opt/git/test.git
 * [new branch]      master -> master
```

Method Two: create a local `test` repository and then use this to initialize the "bare" repository on the server.

```bash
$ mkdir testrepo
$ cd testrepo
$ git init
Initialized empty Git repository in /cidershare/prod/git/tests/testrepo/.git/

$ echo "wow" >> file.txt
$ git add .
$ git commit -m 'initial commit from john'
[master (root-commit) 026a699] initial commit from john
 1 file changed, 1 insertion(+)
 create mode 100644 file.txt

$ git remote add origin git@FQDN:/opt/git/test.git
$ git push origin master
Counting objects: 3, done.
Writing objects: 100% (3/3), 226 bytes | 0 bytes/s, done.
Total 3 (delta 0), reused 0 (delta 0)
To git@FQDN:/opt/git/test.git
 * [new branch]      master -> master
```

git remote set-url origin https://github.com/USERNAME/REPOSITORY_2.git
