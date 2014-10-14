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

Enter the following. We'll create the root directory for `test-php` shortly after this step.

```nginx


```

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

Restart processes.

```bash
```


## Install Icinga-Web











sudo apt-get install nginx                                  fcgiwrap icinga-cgi icinga-common icinga-core icinga-doc

sudo apt-get install php5 
 php5-mysql 


git clone git://git.icinga.org/icinga-web.git

* PHP 5.2.6+ (cli, pear, xmlrpc, xsl, soap, gd, ldap, json, gettext, sockets)
* PHP PDO MySQL or PostgreSQL
* MySQL or PostgreSQL database for the internal backend (sesssions, etc)
* XML Syntax-highlighting for your preferred editor



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
