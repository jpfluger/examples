> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Icinga2 central server using nginx and postgresql

Let's be very clear. There are two components to monitoring. 

* Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
* Clients: Any server we want to monitor will have Nagios Remote Plugin Executor (NRPE)

The examples below cover setting up the **Central Server**. For setting up the **Client** to communicate with Icinga, see [this example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nagios-npre-client.md).

They assume a core Ubuntu 14.04 installation with a fully-qualified-domain-name of 'icinga.example.com'. The server name should be configured in DNS and accessible via ssh.

> Note: The examples were compiled chiefly from these sources: [Icinga 2 Getting Started Documentation](http://docs.icinga.org/icinga2/latest/doc/module/icinga2/chapter/getting-started#installing-requirements), GitHub [Install Readme](https://github.com/Icinga/icinga-web/blob/master/doc/INSTALL) for Icinga-Web and [Icincga-Web From Scratch](http://docs.icinga.org/latest/en/icinga-web-scratch.html).

## Installation

I chose Icinga instead of Nagios because I wanted to integrate with Postgres. Also the web-interface is slick and, since Icinga is a fork of Nagios, any plugins developed for Nagios will work in Icinga.

Let's install the Icinga `ppa` on Ubuntu 14.04.

```bash
sudo add-apt-repository ppa:formorer/icinga
sudo apt-get update
sudo apt-get install icinga2
```

Verify the install via the enable-feature command `icinga2-enable-feature`.

```bash
$ icinga2-enable-feature

#OUTPUT
Syntax: icinga2-enable-feature <features separated with whitespaces>
  Example: icinga2-enable-feature checker notification mainlog
Enables the specified feature(s).

Available features: api checker command compatlog debuglog graphite icingastatus livestatus mainlog notification perfdata statusdata syslog 
Enabled features: checker mainlog notification 
```

During the setup, the installer created the `nagios` user and group. This is the default setting in Debian/Ubuntu distributions. It also installed plugins. Remember, Icinga is a fork of Nagios and uses Nagios plugins. On an Debian/Ubuntu system, these are found here:

```bash
ls /usr/lib/nagios/plugins

#OUTPUT
check_apt     check_cluster  check_dummy     check_host  check_ide_smart  check_jabber  check_mrtg      check_nntp   check_ntp       check_nwstat  check_pop    check_rta_multi  check_smtp  check_ssmtp  check_time  check_users  utils.pm
check_by_ssh  check_dhcp     check_file_age  check_http  check_imap       check_load    check_mrtgtraf  check_nntps  check_ntp_peer  check_overcr  check_procs  check_sensors    check_spop  check_swap   check_udp   negate       utils.sh
check_clamd   check_disk     check_ftp       check_icmp  check_ircd       check_log     check_nagios    check_nt     check_ntp_time  check_ping    check_real   check_simap      check_ssh   check_tcp    check_ups   urlize
```

More plugins are available via [The Monitoring Plugins](https://www.monitoring-plugins.org/) project, for which an ubuntu package can install them:

```bash
sudo apt-get install nagios-plugins

#OUTPUT
check_apt      check_dbi       check_dns       check_host       check_ifoperstatus  check_ldap   check_mrtg         check_nntp      check_ntp_time  check_ping   check_rta_multi  check_spop   check_time   negate
check_breeze   check_dhcp      check_dummy     check_hpjd       check_ifstatus      check_ldaps  check_mrtgtraf     check_nntps     check_nwstat    check_pop    check_sensors    check_ssh    check_udp    urlize
check_by_ssh   check_dig       check_file_age  check_http       check_imap          check_load   check_mysql        check_nt        check_oracle    check_procs  check_simap      check_ssmtp  check_ups    utils.pm
check_clamd    check_disk      check_flexlm    check_icmp       check_ircd          check_log    check_mysql_query  check_ntp       check_overcr    check_real   check_smtp       check_swap   check_users  utils.sh
check_cluster  check_disk_smb  check_ftp       check_ide_smart  check_jabber        check_mailq  check_nagios       check_ntp_peer  check_pgsql     check_rpc    check_snmp       check_tcp    check_wave
```

See the [Icinga 2 Getting Started Documentation](http://docs.icinga.org/icinga2/latest/doc/module/icinga2/chapter/getting-started#installing-requirements) for integrating additional plugins.

## Install Postgresql

Install postgresql.

```bash
sudo apt-get install postgresql
```

Install the icinga2 module that communicates with postgresql. For the password in this example, I used `"icinga"`.

```bash
sudo apt-get install icinga2-ido-pgsql

# WIZARD 1 --> Choose YES
# WIZARD 2 --> Choose YES
# WIZARD 3 --> Enter and verify password ("icinga")
```

Login to postgres.

```bash
sudo -u postgres psql
```

Notice the root user password has not been set. Let's fix that. While still logged into postgres, type:

```sql
postgres=# \password postgres
Enter new password: <PASSWORD>
Enter it again:  <PASSWORD>
```

Now list the databases. Icinga create `icinga2idopgsql`.

```sql
postgres=# \list

#OUTPUT
                                     List of databases
      Name       |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------------+----------+----------+-------------+-------------+-----------------------
 icinga2idopgsql | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 postgres        | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0       | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |          |             |             | postgres=CTc/postgres
 template1       | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
                 |          |          |             |             | postgres=CTc/postgres
```

A default Icinga user was created too.

```bash
postgres=# \du

#OUTPUT
                                List of roles
    Role name    |                   Attributes                   | Member of 
-----------------+------------------------------------------------+-----------
 icinga2idopgsql |                                                | {}
 postgres        | Superuser, Create role, Create DB, Replication | {}
```

Switch to the Icinga database.

```bash
postgres=# \c icinga2idopgsql

#OUTPUT
SSL connection (cipher: DHE-RSA-AES256-SHA, bits: 256)
You are now connected to database "icinga2idopgsql" as user "postgres".
```

List the tables that were auto-created.

```bash
icinga2idopgsql-# \dl *.*

#OUTPUT (SHOWING Icinga-created tables)
 public             | icinga_acknowledgements                | table | icinga2idopgsql
 public             | icinga_commands                        | table | icinga2idopgsql
 public             | icinga_commenthistory                  | table | icinga2idopgsql
 public             | icinga_comments                        | table | icinga2idopgsql
 public             | icinga_configfiles                     | table | icinga2idopgsql
 public             | icinga_configfilevariables             | table | icinga2idopgsql
 public             | icinga_conninfo                        | table | icinga2idopgsql
 public             | icinga_contact_addresses               | table | icinga2idopgsql
 public             | icinga_contact_notificationcommands    | table | icinga2idopgsql
 public             | icinga_contactgroup_members            | table | icinga2idopgsql
 public             | icinga_contactgroups                   | table | icinga2idopgsql
 public             | icinga_contactnotificationmethods      | table | icinga2idopgsql
 public             | icinga_contactnotifications            | table | icinga2idopgsql
 public             | icinga_contacts                        | table | icinga2idopgsql
 public             | icinga_contactstatus                   | table | icinga2idopgsql
 public             | icinga_customvariables                 | table | icinga2idopgsql
 public             | icinga_customvariablestatus            | table | icinga2idopgsql
 public             | icinga_dbversion                       | table | icinga2idopgsql
 public             | icinga_downtimehistory                 | table | icinga2idopgsql
 public             | icinga_endpoints                       | table | icinga2idopgsql
 public             | icinga_endpointstatus                  | table | icinga2idopgsql
 public             | icinga_eventhandlers                   | table | icinga2idopgsql
 public             | icinga_externalcommands                | table | icinga2idopgsql
 public             | icinga_flappinghistory                 | table | icinga2idopgsql
 public             | icinga_host_contactgroups              | table | icinga2idopgsql
 public             | icinga_host_contacts                   | table | icinga2idopgsql
 public             | icinga_host_parenthosts                | table | icinga2idopgsql
 public             | icinga_hostchecks                      | table | icinga2idopgsql
 public             | icinga_hostdependencies                | table | icinga2idopgsql
 public             | icinga_hostescalation_contactgroups    | table | icinga2idopgsql
 public             | icinga_hostescalation_contacts         | table | icinga2idopgsql
 public             | icinga_hostescalations                 | table | icinga2idopgsql
 public             | icinga_hostgroup_members               | table | icinga2idopgsql
 public             | icinga_hostgroups                      | table | icinga2idopgsql
 public             | icinga_hosts                           | table | icinga2idopgsql
 public             | icinga_hoststatus                      | table | icinga2idopgsql
 public             | icinga_instances                       | table | icinga2idopgsql
 public             | icinga_logentries                      | table | icinga2idopgsql
 public             | icinga_notifications                   | table | icinga2idopgsql
 public             | icinga_objects                         | table | icinga2idopgsql
 public             | icinga_processevents                   | table | icinga2idopgsql
 public             | icinga_programstatus                   | table | icinga2idopgsql
 public             | icinga_runtimevariables                | table | icinga2idopgsql
 public             | icinga_scheduleddowntime               | table | icinga2idopgsql
 public             | icinga_service_contactgroups           | table | icinga2idopgsql
 public             | icinga_service_contacts                | table | icinga2idopgsql
 public             | icinga_servicechecks                   | table | icinga2idopgsql
 public             | icinga_servicedependencies             | table | icinga2idopgsql
 public             | icinga_serviceescalation_contactgroups | table | icinga2idopgsql
 public             | icinga_serviceescalation_contacts      | table | icinga2idopgsql
 public             | icinga_serviceescalations              | table | icinga2idopgsql
 public             | icinga_servicegroup_members            | table | icinga2idopgsql
 public             | icinga_servicegroups                   | table | icinga2idopgsql
 public             | icinga_services                        | table | icinga2idopgsql
 public             | icinga_servicestatus                   | table | icinga2idopgsql
 public             | icinga_statehistory                    | table | icinga2idopgsql
 public             | icinga_systemcommands                  | table | icinga2idopgsql
 public             | icinga_timeperiod_timeranges           | table | icinga2idopgsql
```

Quit from postgres with the `\q` command.

```sql
postgres=# \q
```

For future reference, you may connect to postgres locally using `psql` but you will be prompted for your password. It's a good way to test that your password change took effect earlier.

```bash
psql -U postgres -h localhost

# OR for the Icinga user
psql -U icinga2idopgsql -h localhost
```

If you need to change the Icinga module that points to Postgres, edit `/etc/icinga2/features-available/ido-pgsql.conf`.

Enable the `ido-pgsql` module

```bash
sudo icinga2-enable-feature ido-pgsql
```

Restart services.

```bash
sudo service postgresql restart
sudo service icinga2 restart
```

Check its status.

```bash
sudo service icinga2 status

#OUTPUT
 * icinga2 is running
 ```

## Configure nginx and php

Install nginx, php and postgres dependencies.

```bash
sudo apt-get install nginx php5-fpm php-apc php5-pgsql php5-cli php-pear php5-xmlrpc php5-xsl php-soap php5-gd php5-ldap php5-json
```

By default nginx launches a web page that can now be accessed by your client browser.

```
http://icinga.example.com
```

But we do not want to use the `default` settings. Follow [this guide](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx-proxy.md) to setup nginx as a proxy but feel free to leave out the `myapp` configuration.

Instead let's create a new nginx site that will test our php installation. 

```bash
sudo vim /etc/nginx/sites-available/icinga.example.com
```

Enter the following. We'll create the root directory for `test-php` and the user-password file after this step.

```nginx
#VERSION: "test-php"
server {
   listen      192.168.1.3:80;
   server_name icinga.example.com;
   access_log  /var/log/nginx/icinga.example.com.access.log  main;
   error_log   /var/log/nginx/icinga.example.com.error.log;
   root        /path/to/root/folder/test-php;
   index       index.php;

   location / {
      auth_basic   "Restricted";
      auth_basic_user_file  /home/avatar/htpasswd.users;
   }

   location ~ \.php$ {
      try_files $uri =404;
      fastcgi_pass unix:/var/run/php5-fpm.sock;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      include fastcgi_params;
   }
}
```

---

Create the `test-php` root directory and open `index.php` in an editor.

```bash
mkdir ~/test-php
vim ~/test-php/index.php
```

Paste this into `index.php`.

```php
<?php
  phpinfo( );
?>
```

---

#I DON'T THINK WE NEED THIS ANYMORE (for icinga classic ?)

We'll need the `htpasswd` utility from the apache2 project. We are only installing the utilities and not apache2 itself.

```bash
sudo apt-get install apache2-utils
```

Crate the htpasswd.users file in the root web folder with the username of `icingaadmin`. You will be prompted to enter a password.

```bash
htpasswd -c /path/to/root/folder/htpasswd.users icingaadmin
```

---

Enable the site and restart services.

```bash
sudo nginx_modsite -d default
sudo nginx_modsite -e icinga.example.com
sudo service nginx restart
```

Reload your browser. You should now see the information passed back from `phpinfo()`.

```
http://icinga.example.com
```
## Install Icinga-Web

For this example, the root folder of the website will be /home/USER/icinga-web. This example uses release v1.11.2. See [this website](https://github.com/Icinga/icinga-web/releases) for the latest production releases.

Download using `wget`.

```bash
cd ~/
wget https://github.com/Icinga/icinga-web/releases/download/v1.11.2/icinga-web-1.11.2.tar.gz
```

Extract.

```bash
tar xzvf icinga-web-1.11.2.tar.gz
```

Create the production directory for this website.

```bash
mkdir -p ~/prod/icinga-web
```

Dive into postgres and create the icinga_web role and database.

```
$ sudo -u postgres psql
```

Enter the following postgres commands. Change the default PASSWORD of `icinga_web` to something more secure.

```
postgres=# CREATE USER icinga_web WITH PASSWORD 'icinga_web';
  CREATE ROLE
postgres=# CREATE DATABASE icinga_web;
  CREATE DATABASE
postgres=# \q
```

Give the user `icinga_web` trusted authentication rights to start-stop postgresql by adding the following  to `pg_hba.conf`.  First open the file.

```bash
sudo vim /etc/postgresql/9.3/main/pg_hba.conf
```

At the bottom, add:

```
local   icinga_web      icinga_web                            trust
host    icinga_web      icinga_web      127.0.0.1/32          trust
host    icinga_web      icinga_web      ::1/128               trust
```

Restart postgresql.

```bash
sudo service postgresql restart
```

Let's change into folder of the tarball we just extracted.

```bash
cd icinga-web-1.11.2/
```

Create the icinga_web database objects by importing them in from the existing schema file.  

```bash
psql -U icinga_web -d icinga_web -h localhost -a -f etc/schema/pgsql.sql
```

Configure the site. 

```
./configure \
                --prefix=/home/avatar/prod/icinga-web \
                --with-web-user=www-data \
                --with-web-group=www-data \
                --with-web-path=/icinga-web \
				--with-db-type=pgsql \
				--with-db-port=5432 \
                --with-db-host=localhost \
				--with-api-subtype=pgsql \
				--with-api-port=5432 \
                --with-api-host=localhost \
                --with-db-name=icinga_web \
                --with-db-user=icinga_web \
                --with-db-pass=icinga_web \
                --with-log-dir=/var/log

#END OF OUTPUT
icinga-web successfully configured!

Please proceed with make to install your icinga-web instance:

 * make               Some general hints about make targets
 * make install       Install a new instance of icinga-web
 * make upgrade       Upgrades an existing installation:
                      keep site config files untouched!
```

We need make installed before we can `make install`.

```bash
sudo apt-get install make
```

Install it.

```bash
sudo make install

#END OF OUTPUT
Installation if icinga-web succeeded.

Please check the new Apache2 configuration (/etc/apache2/conf.d/icinga-web.conf).

You can install it simply by invoking 'make install-apache-config'.

If you don't want this you can restore its old behavior by
typing 'make install-javascript'. This will install the old symlinks.

If you want to setup your database manually, you can find the scripts 
at etc/schema, otherwise use make db-initialize.

Have fun!
```

Test php dependencies.

```bash
sudo make testdeps

#END OF OUTPUT
All over result: PASS (required 12/12, optional 9/11, all 21/23, time 0.01s)

Exit (status=0)
```

## Bringing up the website with nginx

TO-DO..... 

[Thank You!](http://www.monitoring-portal.org/wbb/index.php?page=Thread&threadID=29035)

...will update soon.

* Default user: `root`
* Default password: `password`


---
---
---


## Configurations

Enable the External Command Pipe using to allow web interfaces and other Icinga addons send commands.

```bash
sudo icinga2-enable-feature command
```

Restart, so changes take effect.

```bash
sudo service icinga2 restart
```

Here are the packages that were installed in this example.

```bash
sudo dpkg -l | grep icinga2

#OUTPUT
ii  icinga2                              2.1.1-1~ppa1~trusty1          amd64        host and network monitoring system
ii  icinga2-bin                          2.1.1-1~ppa1~trusty1          amd64        host and network monitoring system - daemon
ii  icinga2-common                       2.1.1-1~ppa1~trusty1          all          host and network monitoring system - common files
ii  icinga2-doc                          2.1.1-1~ppa1~trusty1          all          host and network monitoring system - documentation
ii  icinga2-ido-pgsql                    2.1.1-1~ppa1~trusty1          amd64        host and network monitoring system - PostgreSQL support
ii  python-icinga2                       2.1.1-1~ppa1~trusty1          all          host and network monitoring system - Python module
```

## Configuration

Here's how the installer configured the Icinga2 `/etc/icinga2` directory:

```bash
$ ls /etc/icinga2

#OUTPUT
conf.d  constants.conf  features-available  features-enabled  icinga2.conf  pki  scripts  zones.conf  zones.d

$ ls /etc/icinga2/conf.d

#OUTPUT
commands.conf  downtimes.conf  groups.conf  hosts  notifications.conf  services.conf  templates.conf  timeperiods.conf  users.conf


$ ls /etc/icinga2/features-enabled/

#OUTPUT
checker.conf  mainlog.conf  notification.conf

$ ls /etc/icinga2/features-available

#OUTPUT
api.conf  checker.conf  command.conf  compatlog.conf  debuglog.conf  graphite.conf  icingastatus.conf  livestatus.conf  mainlog.conf  notification.conf  perfdata.conf  statusdata.conf  syslog.conf
```
