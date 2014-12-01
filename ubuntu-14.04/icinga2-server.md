> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Icinga2 central server using nginx and postgresql

Let's be very clear about the multiple components needed for monitoring. It's not difficult but can be confusing if not clearly communicated from the outset.

1. Central Server: we are using Icinga2 for the core and Icinga-Web for the GUI (version 2 of the web interface is still under "heavy development")
2. Clients: Any server we monitor will be monitored in one of two ways:
   1. The central server uses ping, http or other commands to execute against the targeted device. No modules are installed on the targeted device.
   2. Install a client module on the remote device, which can then communicate with Icinga2
      * On Linux, install Nagios Remote Plugin Executor (NRPE) on the remote Linux device.
      * On Windows, install NSClient++'s NRPE service on the remote Windows device.

The examples below cover setting up the **Central Server** and monitoring from the Central Server outwards towards targeted host devices. For setting up [NRPE](http://exchange.nagios.org/directory/Addons/Monitoring-Agents/NRPE--2D-Nagios-Remote-Plugin-Executor/details) or [NSClient](http://www.nsclient.org/about/) to communicate with Icinga, see [the NRPE Ubuntu 14.04 example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nagios-npre-client.md) or [the NSClient++ Windows 8.1 example](https://github.com/jpfluger/examples/blob/master/windows/nsclient-windows.md).

---

The core server assumes a default Ubuntu 14.04 installation with a fully-qualified-domain-name of 'icinga.example.com'. The server name should be configured in DNS and accessible via ssh. For the example below, I used an IP of 192.168.1.3.

This example will be covering the following:

* [Install Icinga2](#install-icinga2)
* [Icinga2 Tweaks for Commands and Testing](#icinga2-tweaks-for-commands-and-testing)
* [Install Postgresql and let Icinga2 use it for storage](#install-postgresql-and-let-icinga2-use-it-for-storage)
* [Install Nginx, PHP and Postgres dependencies](#install-nginx-php-and-postgres-dependencies)
* [Install Icinga-Web (not Icinga-Classic nor Icinga-Web2)](#install-icinga-web)
* [Run Icinga-Web using Nginx](#run-icinga-web-using-nginx)
* [Tests](#tests)
* [Ping a 2nd Host and Additional Configurations](#ping-a-2nd-host-and-additional-configurations)
* [My Default Setup (for comparison)](#my-default-setup-for-comparison)
* [Updates to Icinga2](#updates-to-icigna2)
* [Setup HTTP API](#setup-http-api)
* [Parameters for Icinga Web API](#parameters-for-icinga-web-api)

I chose Icinga instead of Nagios because I wanted to integrate with Postgres. Also the web-interface is slick and, since Icinga is a fork of Nagios, plugins developed for Nagios work in Icinga.

> Note: The examples were compiled chiefly from these sources: [Icinga 2 Getting Started Documentation](http://docs.icinga.org/icinga2/latest/doc/module/icinga2/chapter/getting-started#installing-requirements) and GitHub [Install Readme](https://github.com/Icinga/icinga-web/blob/master/doc/INSTALL) for Icinga-Web.

## Install Icinga2

Let's install the Icinga `ppa` on Ubuntu 14.04.

```bash
$ sudo add-apt-repository ppa:formorer/icinga
$ sudo apt-get update
$ sudo apt-get install icinga2
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

> Note 1: `icinga2-enable-feature <NAME-OF-FEATURER>` will enable a feature and `icinga2-disable-feature <NAME-OF-FEATURER>` will disable a feature. An icinga2 restart is required after enabling or disabling features.

> Note 2: By default the `notification` feature uses email for notifications. Digital Ocean has a [tutorial](https://www.digitalocean.com/community/tutorials/how-to-install-and-setup-postfix-on-ubuntu-14-04) on setting up simple email no Ubuntu 14.04.

During setup, the installer created the `nagios` user and group. However, the icinga2-command daemon uses `www-data` as the group. This allows the website we configure later to uses its default `www-data` group to send commands to icinga2. These are the default setting set for us during the icinga2 Debian/Ubuntu apt package installation. 

APT also installed plugins. We will refer to these in our host definitions later. For now though, feel free to check-out the available commands. On an Debian/Ubuntu system, these are found here:

```bash
$ ls /usr/lib/nagios/plugins

#OUTPUT
check_apt     check_cluster  check_dummy     check_host  check_ide_smart  check_jabber  check_mrtg      check_nntp   check_ntp       check_nwstat  check_pop    check_rta_multi  check_smtp  check_ssmtp  check_time  check_users  utils.pm
check_by_ssh  check_dhcp     check_file_age  check_http  check_imap       check_load    check_mrtgtraf  check_nntps  check_ntp_peer  check_overcr  check_procs  check_sensors    check_spop  check_swap   check_udp   negate       utils.sh
check_clamd   check_disk     check_ftp       check_icmp  check_ircd       check_log     check_nagios    check_nt     check_ntp_time  check_ping    check_real   check_simap      check_ssh   check_tcp    check_ups   urlize
```

More plugins are available via [The Monitoring Plugins](https://www.monitoring-plugins.org/) project. Install these now:

```bash
$ sudo apt-get install nagios-plugins
```

Refresh the plugins list.

```bash
$ ls /usr/lib/nagios/plugins

#OUTPUT
check_apt      check_dbi       check_dns       check_host       check_ifoperstatus  check_ldap   check_mrtg         check_nntp      check_ntp_time  check_ping   check_rta_multi  check_spop   check_time   negate
check_breeze   check_dhcp      check_dummy     check_hpjd       check_ifstatus      check_ldaps  check_mrtgtraf     check_nntps     check_nwstat    check_pop    check_sensors    check_ssh    check_udp    urlize
check_by_ssh   check_dig       check_file_age  check_http       check_imap          check_load   check_mysql        check_nt        check_oracle    check_procs  check_simap      check_ssmtp  check_ups    utils.pm
check_clamd    check_disk      check_flexlm    check_icmp       check_ircd          check_log    check_mysql_query  check_ntp       check_overcr    check_real   check_smtp       check_swap   check_users  utils.sh
check_cluster  check_disk_smb  check_ftp       check_ide_smart  check_jabber        check_mailq  check_nagios       check_ntp_peer  check_pgsql     check_rpc    check_snmp       check_tcp    check_wave
```

Other commands, such as `ping4`, are found in the [Icinga Template Library](http://icinga2.readthedocs.org/en/latest/chapter-5.html) (ITL). The `include` directory for ITL is in `/usr/share/icinga2/include/`. 

Here are some of the ITL commands provided by `command-plugins.conf`.

```bash
$ sudo cat /usr/share/icinga2/include/command-plugins.conf | grep CheckCommand

 #OUTPUT
template CheckCommand "ping-common" {
object CheckCommand "ping4" {
object CheckCommand "ping6" {
object CheckCommand "hostalive" {
template CheckCommand "fping-common" {
object CheckCommand "fping4" {
object CheckCommand "fping6" {
object CheckCommand "dummy" {
object CheckCommand "passive" {
object CheckCommand "tcp" {
object CheckCommand "ssl" {
object CheckCommand "udp" {
object CheckCommand "http" {
object CheckCommand "ftp" {
object CheckCommand "smtp" {
object CheckCommand "ssmtp" {
object CheckCommand "imap" {
object CheckCommand "simap" {
object CheckCommand "pop" {
object CheckCommand "spop" {
object CheckCommand "ntp_time" {
object CheckCommand "ssh" {
object CheckCommand "disk" {
object CheckCommand "users" {
object CheckCommand "procs" {
object CheckCommand "swap" {
object CheckCommand "load" {
object CheckCommand "snmp" {
object CheckCommand "snmpv3" {
object CheckCommand "snmp-uptime" {
object CheckCommand "apt" {
object CheckCommand "dhcp" {
object CheckCommand "dns" {
object CheckCommand "dig" {
object CheckCommand "nscp" {
object CheckCommand "by_ssh" {
object CheckCommand "ups" {
object CheckCommand "nrpe" {
object CheckCommand "running_kernel" {
```

A template is reusable. In the output above, `ping4` and `ping6` inherit from `ping-common` and use those properties to run its checks.

---

Icinga2 offers suggestions on what you need to do to design your own plugin. See the [Icinga 2 Getting Started Documentation](http://docs.icinga.org/icinga2/latest/doc/module/icinga2/chapter/getting-started#installing-requirements) for integrating additional plugins.

## Icinga2 Tweaks for Commands and Testing

Let's test the installation so far.

```bash
$ sudo -u nagios /usr/lib/nagios/plugins/check_ping -4 -H 127.0.0.1 -c 5000,100% -w 3000,80%

#OUTPUT
PING OK - Packet loss = 0%, RTA = 0.06 ms|rta=0.063000ms;3000.000000;5000.000000;0.000000 pl=0%;80;100;0
```

Add the `nagios` user to the `www-data` group.

```bash
$ sudo usermod -a -G nagios www-data
```

Let's enable the `command` feature.

```bash
$ sudo icinga2-enable-feature command
$ sudo service icinga2 restart
```

Check that we can pipe a command to Icinga2. This is how the Icinga-Web interface will pass instructions to Icinga2.

```bash
 $ sudo -u nagios /bin/echo "[`date +%s`] SCHEDULE_FORCED_SVC_CHECK;localhost;ping4;`date +%s`" >> /var/run/icinga2/cmd/icinga2.cmd
-bash: /var/run/icinga2/cmd/icinga2.cmd: Permission denied
```

Did that work for you?  No?  It didn't work for me and even replacing `nagios` with `www-data` will fail. **BUT** the command does work for the website we configure later. If we do need to execute this command from the terminal, the solution is to add the current user to the `www-data` group.

```bash
$ sudo usermod -a -G www-data `id -un`
```

Logout and then back in for the new group to be recognized. Rerun the command above successfully.

## Install Postgresql and let Icinga2 use it for storage

Install postgresql.

```bash
$ sudo apt-get install postgresql
```

Install the icinga2 module that communicates with postgresql.

```bash
$ sudo apt-get install icinga2-ido-pgsql

# WIZARD 1 --> Choose YES
# WIZARD 2 --> Choose NO (we'll set this manually)
```

Login to postgres.

```bash
$ sudo -u postgres psql
```

The postgres `root` user password is not set by default. Let's fix that. While still logged into postgres, type:

```
postgres=# \password postgres
Enter new password: <ROOT-POSTGRES-PASSWORD>
Enter it again:  <ROOT-POSTGRES-PASSWORD>
```

Logout of postgres.

```
postgres=# \q
```

Create the role for the icinga2 user. For the example, I made both role and password the same, `"icinga"`.

```bash
$ sudo -u postgres psql -c "CREATE ROLE icinga WITH LOGIN PASSWORD 'icinga'";
$ sudo -u postgres createdb -O icinga -E UTF8 icinga
```

---

Add the icinga user with md5 authentication to `pg_hba.conf`. The asterisk (*) takes place of "9.3", which is the version of postgres installed on my machine. If multiple versions of Postgres are installed, change the asterisk to the desired version.

```bash
$ sudo vim /etc/postgresql/*/main/pg_hba.conf
```

Slip in the non-local connections for `icinga` between "Put your actual configurations here" and "DO NOT DISABLE!".

```vim
# Put your actual configuration here
# ----------------------------------
#
# If you want to allow non-local connections, you need to add more
# "host" records.  In that case you will also need to make PostgreSQL
# listen on a non-local interface via the listen_addresses
# configuration parameter, or via the -i or -h command line switches.

# icinga
local   icinga      icinga                            md5
host    icinga      icinga      127.0.0.1/32          md5
host    icinga      icinga      ::1/128               md5

# DO NOT DISABLE!
# If you change this first entry you will need to make sure that the
# database superuser can access the database using some other method.
# Noninteractive access to all databases is required during automatic
# maintenance (custom daily cronjobs, replication, and similar tasks).
```

Restart postgres.

```bash
$ sudo service postgresql restart
```

---

Import into the `icinga` database the schema found in `/usr/share/icinga2-ido-pgsql/schema`.

```bash 
$ psql -U icinga -d icinga < /usr/share/icinga2-ido-pgsql/schema/pgsql.sql
```

Update ido-pgsql.conf.

```bash
$ sudo vim /etc/icinga2/features-available/ido-pgsql.conf 
```

Input the database credentials for `icinga`.

```vim
/**
 * The db_ido_pgsql library implements IDO functionality
 * for PostgreSQL.
 */

library "db_ido_pgsql"

object IdoPgsqlConnection "ido-pgsql" {
  user = "icinga",
  password = "icinga",
  host = "localhost",
  database = "icinga"
}
```

Enable the `ido-pgsql` modules because the install wizard **did not** do it for me.

```bash
$ sudo icinga2-enable-feature ido-pgsql
```

Restart icinga2.

```bash
$ sudo service icinga2 restart
```

## Install Nginx, PHP and Postgres dependencies

Install nginx, php and postgres dependencies.

```bash
$ sudo apt-get install nginx php5-fpm php-apc php5-pgsql php5-cli php-pear php5-xmlrpc php5-xsl php-soap php5-gd php5-ldap php5-json
```

By default nginx launches a web page that can now be accessed by your client browser. Assuming you have DNS pointed to `icinga.example.com`, bring up in a web browser:

```
http://icinga.example.com
```

A little nginx maintenance. Each of the two links below point to a section to follow to complete the nginx setup.

  1. [Modify nginx.conf](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx-proxy.md#modify-nginxconf)
  2. [Simplify nginx administration](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx-proxy.md#simplify-nginx-administration)

---

Create the `test-php` root directory and open `index.php` in an editor. For this example, I'm using `/var/www/test-php` as the root web server folder.

```bash
$ sudo mkdir -p /var/www/test-php
$ sudo vim /var/www/test-php/index.php
```

Paste this into `index.php`.

```php
<?php
  phpinfo( );
?>
```

---

Let's create a new nginx site that will test our php installation. 

```bash
$ sudo vim /etc/nginx/sites-available/test-php
```

Enter the following. Change `server_name` and the log file names, as necessary. No need for a user-password becuase we'll disable this site after validating php.info() is correct.

```nginx
#VERSION: "test-php"
server {
   listen      0.0.0.0:80;
   server_name icinga.example.com;
   access_log  /var/log/nginx/icinga.example.com.access.log  main;
   error_log   /var/log/nginx/icinga.example.com.error.log;
   root        /var/www/test-php;
   index       index.php;

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

Change the default timezone for php, else Icinga-Web will show GMT.

What does `cat /etc/timezone` return?

```bash
$ cat /etc/timezone

#OUTPUT
America/Chicago
```

Change `php.ini`.

```bash
$ sudo vim /etc/php5/fpm/php.ini
```

Find `timezone` and comment it in.

```php
[Date]
; Defines the default timezone used by the date functions
; http://php.net/date.timezone
date.timezone = America/Chicago
```

Restart php services.

```bash
$ sudo service php5-fpm restart
```

---

Disable the `default` nginx site.

```bash
$ sudo nginx_modsite -d default
```

Enable `test-php`.

```bash
$ sudo nginx_modsite -e test-php
```

Restart nginx.

```bash
$ sudo service nginx restart
```

Reload your browser. You should now see the information passed back from `phpinfo()`.  Timezone should be set to `US/Central`.

```
http://icinga.example.com
```

## Install Icinga-Web

We are going to install Icinga-Web, which is not Icinga-Classic nor Icinga-Web2. Icinga-Web is compatible with both Icinga and Icinga2 modules. Many of the Debian/Ubuntu-related tutorials on the internet are for Icinga-Classic. This example is not Icinga-Classic; it is for Icinga-Web, which is Icinga's current "flagship" interface. Please see [this page](https://www.icinga.org/icinga/screenshots/) to begin investigating differences.

In order to get Icinga-Web to behave with nginx, we are going build and install Icinga-Web in one site and then point the Nginx website to it. When finished, it will look like this:

* ~/icinga-web-1.11.2: This is the unpackaged source file or clone from GitHub. We configure the installation here. `make` will install the installation to a folder we specify.
* /usr/share/icinga-web: This is the directory in which `make` will install icinga-web. If we were running Apache, an Apache configuration file would have already been pre-generated and would point to this directory. But we are using Nginx, so add a 3rd directory which will symlink back to this one.
* /var/www/icinga: This is the root of the Nginx directory that gets symlinked back to /usr/share/icinga-web. 

This example uses release v1.11.2. See [this website](https://github.com/Icinga/icinga-web/releases) for the latest production releases.

Download using `wget`.

```bash
$ cd ~/
$ wget https://github.com/Icinga/icinga-web/releases/download/v1.11.2/icinga-web-1.11.2.tar.gz
```

Extract.

```bash
$ tar xzvf icinga-web-1.11.2.tar.gz
```

Create the production directory for this website. 

```bash
$ sudo mkdir -p /usr/share/icinga-web
```

In postgres create the icinga_web role and database.  Change the default PASSWORD of `icinga_web` to something more secure.

```
$ sudo -u postgres psql -c "CREATE ROLE icinga_web WITH LOGIN PASSWORD 'icinga_web'";
$ sudo -u postgres createdb -O icinga_web -E UTF8 icinga_web
```

Give the user `icinga_web` trusted authentication rights to start-stop postgresql by adding the following  to `pg_hba.conf`.

First open the file.

```bash
$ sudo vim /etc/postgresql/*/main/pg_hba.conf
```

Just after the `icinga` entries added above, include:

```
#icinga_web
local   icinga_web      icinga_web                            trust
host    icinga_web      icinga_web      127.0.0.1/32          trust
host    icinga_web      icinga_web      ::1/128               trust
```

Restart postgresql.

```bash
$ sudo service postgresql restart
```

Change into folder of the tarball we just extracted.

```bash
$ cd icinga-web-1.11.2/
```

Create the icinga_web database objects by importing them in from the existing schema file.  

```bash
$ psql -U icinga_web -d icinga_web < etc/schema/pgsql.sql 
```

Configure the site. The target directory is defined by `--prefix`, where we direct it to install to `/usr/share/icinga-web`. 

```
$ ./configure \
          --prefix=/usr/share/icinga-web \
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

We need `make` installed before we can `make install`.

```bash
$ sudo apt-get install make
```

Install it.

```bash
$ sudo make install

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
$ sudo make testdeps

#END OF OUTPUT
All over result: PASS (required 12/12, optional 9/11, all 21/23, time 0.00s)

Exit (status=0)
```

## Run Icinga-Web using Nginx

> Credits: A huge **THANK YOU** goes to "Rancor" [on this thread](http://www.monitoring-portal.org/wbb/index.php?page=Thread&threadID=29035), who posted a working solution for Nginx and Icinga-Web.

Create a new nginx site for `icinga.example.com`. 

```bash
$ sudo vim /etc/nginx/sites-available/icinga.example.com
```

Copy the following into the editor. 

```nginx
#VERSION: "icinga.example.com"
server {
        listen      0.0.0.0:80;
        server_name icinga.example.com;
        access_log  /var/log/nginx/icinga.example.com.access.log  main;
        error_log   /var/log/nginx/icinga.example.com.error.log;
        root        /var/www/icinga;
        index index.php index.html index.htm;

        location = / {
                rewrite ^/$ /icinga-web permanent;
        }

        location /icinga-web/modules/([A-Za-z0-9]*)/resources/images/([A-Za-z_\-0-9]*\.(png|gif|jpg))$ {
                alias /usr/share/icinga-web/app/modules/$1/pub/images/$2;
        }

        location /icinga-web/modules/([A-Za-z0-9]*)/resources/styles/([A-Za-z0-9]*\.css)$ {
                alias /usr/share/icinga-web/app/modules/$1/pub/styles/$2;
        }

        location /icinga-web/modules {
                rewrite ^/icinga-web/(.*)$ /icinga-web/index.php?/$1 last;
        }

        location /icinga-web/web {
                rewrite ^/icinga-web/(.*)$ /icinga-web/index.php?/$1 last;
        }

        location ~ ^/modules {
                rewrite ^/modules/(.*)$ /icinga-web/modules/$1 permanent;
        }

        location ~ /icinga-web/(.*)\.php($|/) {
                include /etc/nginx/fastcgi_params;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
                fastcgi_index index.php;
                fastcgi_split_path_info ^(/icinga-web/.*\.php)(.*);
                fastcgi_param PATH_INFO $fastcgi_path_info;
                fastcgi_param SCRIPT_FILENAME /usr/share/icinga-web/pub/index.php;
        }
}
```

> Note: `listen` is set to `0.0.0.0:80`, which directs nginx to listen on all ip addresses on port 80. This is important as Icinga2's default localhost configuration for `http` has `localhost` as its `hostname`.

Create a symlink from the `lib` folder so that it appears as the `js` directory within `/usr/share/icinga-web/pub`.

```bash
$ sudo ln -s /usr/share/icinga-web/lib /usr/share/icinga-web/pub/js
```

Create the root web folder that nginx is pointed at.

```bash
$ sudo mkdir -p /var/www/icinga
```

Create a symlink from the nginx root to so that it appears as `icinga-web` under the published production web folder, `/var/www/icinga`.

```bash
$ sudo ln -s /usr/share/icinga-web/pub /var/www/icinga/icinga-web
```

Change permissions.

```bash
$ sudo chown -R www-data:www-data /var/www/icinga/icinga-web
$ sudo chown -R www-data:www-data /usr/share/icinga-web
```

---


Change the `icinga-pipe` entry in `access.xml`.


```bash
$ sudo vim /usr/share/icinga-web/etc/conf.d/access.xml
```

Change the path to `/var/run/icinga2/cmd/icinga2.cmd`.

```xml
<!-- allowed to be written to -->
<write>
    <files>
         <resource name="icinga_pipe">/var/run/icinga2/cmd/icinga2.cmd</resource>
    </files>
</write>
 ```

Clear the web-cache. Do this anytime modifications have been made to web config files.

```bash
$ sudo /usr/share/icinga-web/bin/clearcache.sh
```

---

Disable `test-php`.

```bash
$ sudo nginx_modsite -d test-php
```

Enable `icinga.example.com`.

```bash
$ sudo nginx_modsite -e icinga.example.com
```

Restart php and nginx.

```bash
$ sudo service php5-fpm restart
$ sudo service nginx restart
```

---

Refresh your web-browser that points to `icinga.example.com`. You will be redirected to the following:

```
http://icinga.example.com/icinga-web/
```

The default Icinga-Web user and password are the following:

* Default user: `root`
* Default password: `password`

Credentials can be changed after login. On the top-left of the window, you'll see an `Admin` menu. Navigate into there to start administering users.

Your default interface should look like mine with zero errors! (If there is an error (eg Critical is red), try refreshing that panel and it should go away. There's a refresh button to the right of the green "1 OK" notification.)

![Default Icinga-Web Interface](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/icinga2/icinga-web-default.png)

If error hints flash on the top-right of the browser window, the problem could be attributed to a "cronks" database configuration issue.

Open the database configuration file.

```bash
$ sudo vim /usr/share/icinga-web/app/config/databases.xml 
```

Check the database connection string. In my file, the Icinga-Web connection is at the top and the Icinga2 IDO2DB is towards the bottom.

```
# FORMAT of connection string
<ae:parameter name="dsn">pgsql://USERNAME:PASSWORD@localhost:5432/DBNAME</ae:parameter>
```

## Tests

The server we just configured monitors in two ways:

1. Local configs that target an action to itself (eg localhost) or towards a different device (eg using the ping command)
2. Communicating directly with a device using the NRPE module, installed on the other device. See [this example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nagios-npre-client.md) for configuring NRPE on a different device.

As mentioned earlier, plugin commands were installed into `/usr/lib/nagios/plugins/`.

View help for a command by passing the targeted command the `-h` parameter.

```bash
$ sudo /usr/lib/nagios/plugins/check_http -h | less
```

Run a command, passing it arguments.

```bash
$ sudo /usr/lib/nagios/plugins/check_http -H localhost -p 80

#OUTPUT (expected == GOOD)
HTTP OK: HTTP/1.1 301 Moved Permanently - 398 bytes in 0.000 second response time |time=0.000418s;;;0.000000 size=398B;;;0

#OUTPUT (example of what's returned for a non-existent http check)
No route to host
HTTP CRITICAL - Unable to open TCP socket
```

---

Icinga2 global configurations start in `/etc/icinga2/conf.d/` and narrow down to specific devices.

```bash
$ ls /etc/icinga2/conf.d/

#OUTPUT
commands.conf  downtimes.conf  groups.conf  hosts  notifications.conf  services.conf  templates.conf  timeperiods.conf  users.conf
```

Look in hosts. This is where you put your local and target device configurations.

```bash
$ ls /etc/icinga2/conf.d/hosts

#OUTPUT
localhost  localhost.conf
```

Inside `localhost` are the commands that will run for `localhost.conf`.

```bash
$ ls /etc/icinga2/conf.d/hosts/localhost

#OUTPUT
apt.conf  disk.conf  http.conf  icinga.conf  load.conf  procs.conf  ssh.conf  swap.conf  users.conf
```

## Ping a 2nd Host and Additional Configurations

Now is a good time to read through [Monitoring Basics](http://docs.icinga.org/icinga2/latest/doc/module/icinga2/chapter/monitoring-basics#monitoring-basics).

Create a configuration file to monitor `srv1.example.com`, which is the NodeJS web server we setup in other examples (e.g. refer to [Table of Contents](https://github.com/jpfluger/examples)).

```bash
$ sudo vim /etc/icinga2/conf.d/hosts/svr1.conf
```

Add the following, changing ip and hostname information.

```
object Host "srv1.example.com" {
  import "generic-host"
  address = "192.168.1.2"
  check_command = "hostalive"
}

object Service "ping4" {
  import "generic-service"
  host_name = "srv1.example.com"
  check_command = "ping4"
}

object Service "http" {
  import "generic-service"
  host_name = "srv1.example.com"
  check_command = "http"
}
```

Check that configuration syntax is correct.

```bash
$ sudo service icinga2 checkconfig
```

If good, restart Icinga2 and refresh the web interface. 

```bash
$ sudo service icinga2 restart
```

---


In the web interface, you may see some entries have turned purple for `pending`. This status will change but when will it change? How to instruct a Host or Service how quickly it should get updated?

Because our new objects inherit from `generic-host` and `generic-service`, we can see how the default update settings are defined in `templates.conf`.

Open `templates.conf`.

```bash
$ sudo vim `/etc/icinga2/conf.d/templates.conf`
```

Here's how my `generic-host` and `generic-server` templates appear. Notice the default properties to check and retry commands.

```
/**
 * Provides default settings for hosts. By convention
 * all hosts should import this template.
 *
 * The CheckCommand object `hostalive` is provided by
 * the plugin check command templates.
 * Check the documentation for details.
 */
template Host "generic-host" {
  max_check_attempts = 5
  check_interval = 1m
  retry_interval = 30s

  check_command = "hostalive"
}

/**
 * Provides default settings for services. By convention
 * all services should import this template.
 */
template Service "generic-service" {
  max_check_attempts = 3
  check_interval = 1m
  retry_interval = 30s
}
```

---

Optionally group hosts together in some fashion, perhaps by domain-name. We can then view associated hosts or services by group name within Icinga-Web. 

Open the group configuration file.

```bash
$ sudo vim /etc/icinga2/conf.d/groups.conf
```

Add your new `HostGroup` and the search criteria. In my example, `host.varsl.lan` is a custom property that gets auto-created. This means you don't need to define it anywhere else in order for it to be used by any configuration files.

```
object HostGroup "example-com" {
  display_name = "example.com"

  assign where host.vars.lan == "example.com"
}
```

> Note. Services can also be grouped together. That's what the `ServiceGroup` property is for. But in the example below, notice that we do not need to declare a special `ServiceGroup` for our service objects. This is because the service object is already associated with `object Host`; thus, no `vars.lan` property need reside within the individual `object Service` definition.

Open the `svr1.conf` host configuration.

```bash
$ sudo vim /etc/icinga2/conf.d/hosts/svr1.conf
```

Associate the `Host` entry with `vars.lan`.

```
object Host "srv1.example.com" {
  import "generic-host"
  address = "192.168.1.2"
  check_command = "hostalive"

  vars.lan = "example.com"
}

object Service "ping4" {
  import "generic-service"
  host_name = "srv1.example.com"
  check_command = "ping4"
}

object Service "http" {
  import "generic-service"
  host_name = "srv1.example.com"
  check_command = "http"
}
```

Check that configuration syntax is correct.

```bash
$ sudo service icinga2 checkconfig
```

Restart Icinga2.

```bash
$ sudo service icinga2 restart
```

Go to the web interface and refresh it. On the left navigation bar, click on `Host groups` and the `Hostgroups Tab` will appear. Click the icon left of the name, then click `Hosts` or `Services` to inspect them.

A visual overview if Icinga-Web [can be found here](http://docs.icinga.org/latest/en/icinga-web-introduction.html).

---

Services can receive groups too. If we had associated the `object Host` with a Linux or Windows server (e.g. `vars.os = "Linux"`), then the services that had already associated themselves to any Linux or Windows hosts would automatically receive a `ping` check. If that's the case, then our `ping4` check would be unnecessary and actually error. 

Open the service defintion.

```bash
$ sudo vim /etc/icinga2/conf.d/services.conf
```

View how icinga2's default setup already assigns `ping` (ip4 and ip6) to any host with the Linux or Windows label.

```
apply Service "ping4" {
  import "generic-service"

  check_command = "ping4"
  vars.sla = "24x7"

  assign where "linux-servers" in host.groups
  assign where "windows-servers" in host.groups
  ignore where host.address == ""
}

apply Service "ping6" {
  import "generic-service"

  check_command = "ping6"
  vars.sla = "24x7"

  assign where "linux-servers" in host.groups
  assign where "windows-servers" in host.groups
  ignore where host.address6 == ""
}
```

## My Default Setup (for comparison)

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

Icinga-Web version 1.11.2 was installed from tarball.

---

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

We can also jump into postgres and poke-around at the tables just created.

```bash
$ sudo -u postgres psql
```

Now list the databases. 

```postgres
postgres=# \list

#OUTPUT
                                   List of databases
    Name    |   Owner    | Encoding |   Collate   |    Ctype    |   Access privileges   
------------+------------+----------+-------------+-------------+-----------------------
 icinga     | icinga     | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 icinga_web | icinga_web | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 postgres   | postgres   | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0  | postgres   | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
            |            |          |             |             | postgres=CTc/postgres
 template1  | postgres   | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
            |            |          |             |             | postgres=CTc/postgres
(5 rows)
```

A default Icinga user was created too.

```postgres
postgres=# \du

#OUTPUT
                              List of roles
 Role name  |                   Attributes                   | Member of 
------------+------------------------------------------------+-----------
 icinga     |                                                | {}
 icinga_web |                                                | {}
 postgres   | Superuser, Create role, Create DB, Replication | {}
```

Switch to the database `icinga` or `icinga_web`.

```postgres
postgres=# \c icinga
```

List the tables that were auto-created.

```postgres
icinga-# \dl *.*
```

Quit from postgres with the `\q` command.

```sql
postgres=# \q
```

## Updates to Icinga2

The Icinga2 packages for Ubuntu were recently updated, so want to upgrade the version on my device. I found the upgrade process was smooth for a vanilla install but broke my installation that monitors quite a few servers. 

First, upgrade the Icinga2 installation. This is a distribution upgrade, so use the command `dist-upgrade`.

``bash
$ sudo apt-get dist-upgrade
Reading package lists... Done
Building dependency tree       
Reading state information... Done
Calculating upgrade... Done
The following packages will be REMOVED:
  python-icinga2
The following NEW packages will be installed:
  libyajl2 linux-headers-3.13.0-40 linux-headers-3.13.0-40-generic
  linux-image-3.13.0-40-generic linux-image-extra-3.13.0-40-generic
The following packages will be upgraded:
  icinga2 icinga2-bin icinga2-common icinga2-ido-pgsql linux-generic
  linux-headers-generic linux-image-generic
7 upgraded, 5 newly installed, 1 to remove and 0 not upgraded.
Need to get 63.8 MB of archives.
After this operation, 272 MB of additional disk space will be used.
Do you want to continue? [Y/n]
```

Click yes. Eventually we get to the installation of the next Icinga2 version. Conflicts may be found with ping and http (among others), if you have already created these within host configurations. This version of Icinga moved them to a "global" level. 

I identified errors by inspecting the log left from restarting Icinga2.

```bash
$ sudo service icinga2 restart
```

If errors, inspect the startup log.

```bash
$ sudo vim /var/log/icinga2/startup.log 
```

Manually update the database. Update scripts were not installed with the ubuntu package but I did find them on the [Icinga2 GitHub](https://github.com/Icinga/icinga2) repository, particulary in the Postgres [schema upgrade directory](https://github.com/Icinga/icinga2/tree/master/lib/db_ido_pgsql/schema/upgrade).

Login to postgres.

```bash
$ sudo -u postgres psql
```

Connect to Icinga2 and see which version of Icinga database is running.

```sql
postgres=# \c icinga
You are now connected to database "icinga" as user "postgres".
icinga=# select * from icinga_dbversion;
 dbversion_id |   name   | version |          create_time          |          modify_time          
--------------+----------+---------+-------------------------------+-------------------------------
            1 | idoutils | 1.11.7  | 2014-10-24 14:20:38.606363-05 | 2014-10-24 14:20:38.606363-05
```

The [2.2.0.sql](https://github.com/Icinga/icinga2/blob/master/lib/db_ido_pgsql/schema/upgrade/2.2.0.sql) script should be run in order to complete the database upgrade.

```sql
-- -----------------------------------------
-- upgrade path for Icinga 2.2.0
--
-- -----------------------------------------
-- Copyright (c) 2014 Icinga Development Team (http://www.icinga.org)
--
-- Please check http://docs.icinga.org for upgrading information!
-- -----------------------------------------

ALTER TABLE icinga_programstatus ADD COLUMN program_version TEXT default NULL;

ALTER TABLE icinga_customvariables ADD COLUMN is_json INTEGER default 0;
ALTER TABLE icinga_customvariablestatus ADD COLUMN is_json INTEGER default 0;


-- -----------------------------------------
-- update dbversion
-- -----------------------------------------

SELECT updatedbversion('1.12.0');
```

Exit postgres.

```sql
icinga=# \q
```

Restart Icinga2.

```bash
$ sudo service icinga2 restart
```

## Setup HTTP API

According to the [online Icinga-Web documents](http://docs.icinga.org/latest/en/icinga-web-api.html), verify the setup already enabled API usage.

Open `auth.xml`.

```bash
$ sudo vim /usr/share/icinga-web/app/modules/AppKit/config/auth.xml
```

The following section should already be commented in and enabled. If it isn't, then comment it in and enable it.

```xml
<!--
    * api key
    Providing user defined api key in the url to authenticate as fast as possible
    Also please change anything ;-)
-->
<ae:parameter name="auth_key">
    <ae:parameter name="auth_module">AppKit</ae:parameter>
    <ae:parameter name="auth_provider">Auth.Provider.AuthKey</ae:parameter>
    <ae:parameter name="auth_enable">true</ae:parameter>
    <ae:parameter name="auth_authoritative">true</ae:parameter>
</ae:parameter>
```

If the file changed, then also clear the web-cache.

```bash
$ sudo /usr/share/icinga-web/bin/clearcache.sh
```

Login to Icinga-Web.  On the top-left of the window, you'll see an `Admin` menu. Click the `Users` sub-menu item. 

To create a user that has access using the API:

  1. Click the "Add New User" button
  2. Fields
    * username: api-ps
    * name: API
    * surname: Process
    * email: api-ps@example.com
    * Auth via: auth_key
    * Auth key for API: api-ps-12345
    * (SAVE)
  3. On the right-tab, click "Rights" then "Credentials"
    * checkmark true "appkit.api.access"
    * (SAVE)

Let's try a GET request that will pull all services that are ["critical or warning, but have a host that is ok"](http://docs.icinga.org/latest/en/icinga-web-api.html#getexample) and format the results as **json**.

In a web-browser, paste the following but remember to change to your settings:

  * host: icinga.example.com
  * authkey: api-ps-12345
  * json (or for xml, replace with "xml")

```
http://icinga.example.com/icinga-web/web/api/service/filter[AND(HOST_CURRENT_STATE|=|0;OR(SERVICE_CURRENT_STATE|=|1;SERVICE_CURRENT_STATE|=|2))]/
columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_CURRENT_STATE|HOSTGROUP_NAME]/
order(SERVICE_CURRENT_STATE;DESC)/countColumn=SERVICE_ID/authkey=api-ps-12345/json
```

As the online docs tell us, the [structure of the url](http://docs.icinga.org/latest/en/icinga-web-api.html#geturlstructure) has required and optional elements. The required elements are in bold.

example.com/icinga-web/web/api/ **TARGET** / **COLUMNS** / FILTER / ORDER / GROUPING / LIMIT / COUNTFIELD / **OUTPUT_TYPE**

The [parameters](http://docs.icinga.org/latest/en/icinga-web-api.html#getparamdetails)

Here are a few more examples.

Get all hosts being monitored with the current state.

```
http://icinga.example.com/icinga-web/web/api/host/filter/columns[HOST_NAME|HOST_CURRENT_STATE])/authkey=api-ps-12345/json
```

Returns.

```json
{
  "result":[
    {"HOST_NAME":"localhost","HOST_CURRENT_STATE":0,"HOST_IS_PENDING":0}
  ],
  "success":"true"
}
```

Get all services being monitored.

http://icinga.example.com/icinga-web/web/api/service/filter/columns[SERVICE_NAME|HOST_NAME]/authkey=api-ps-12345/json

```json
{
  "result":[
    {"SERVICE_NAME":"load","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"apt","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"http","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"users","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"swap","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"disk","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"ping4","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"ssh","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"procs","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"ping6","HOST_NAME":"localhost"},
    {"SERVICE_NAME":"icinga","HOST_NAME":"localhost"}],
  "success":"true"
}
```

Here's a more detailed list showing the two custom variables, "os" and "sla", for a single host.

```
http://icinga.example.com/icinga-web/web/api/host/filter/columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_ADDRESS|HOST_CUSTOMVARIABLE_NAME|HOST_CUSTOMVARIABLE_VALUE|HOST_CURRENT_STATE|HOSTGROUP_NAME])/authkey=api-ps-12345/json
```

Results.

```json
{
  "result":[
    {"HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0}],
  "success":"true"
}
```

Or by service.

```
http://icinga.example.com/icinga-web/web/api/service/filter/columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_ADDRESS|HOST_CUSTOMVARIABLE_NAME|HOST_CUSTOMVARIABLE_VALUE|HOST_CURRENT_STATE|HOSTGROUP_NAME]/authkey=api-ps-12345/json
```

Results.

```json
{
  "result":[
    {"SERVICE_NAME":"load","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"swap","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ping4","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ssh","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"http","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"apt","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ping6","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"disk","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"procs","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"users","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"icinga","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"apt","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ssh","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ping4","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"http","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"swap","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"load","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"procs","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"users","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"sla","HOST_CUSTOMVARIABLE_VALUE":"24x7","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"icinga","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"disk","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ping6","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0}],
  "success":"true"
}
```

Or filter on the hosts by Custom Variable Name.

```
http://icinga.example.com/icinga-web/web/api/host/filter[AND(HOST_CUSTOMVARIABLE_NAME|=|os;AND(HOST_CUSTOMVARIABLE_VALUE|=|Linux))]/columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_ADDRESS|HOST_CUSTOMVARIABLE_NAME|HOST_CUSTOMVARIABLE_VALUE|HOST_CURRENT_STATE|HOSTGROUP_NAME]/authkey=api-ps-12345/json
```

Results.

```json
{
  "result":[
    {"HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0}],
  "success":"true"
}
```

Or only change **/host/** to **/service/** to search all services.

```
http://icinga.example.com/icinga-web/web/api/service/filter[AND(HOST_CUSTOMVARIABLE_NAME|=|os;AND(HOST_CUSTOMVARIABLE_VALUE|=|Linux))]/columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_ADDRESS|HOST_CUSTOMVARIABLE_NAME|HOST_CUSTOMVARIABLE_VALUE|HOST_CURRENT_STATE|HOSTGROUP_NAME]/authkey=api-ps-12345/json
```

Results.

```json
{
  "result":[
    {"SERVICE_NAME":"disk","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"procs","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"icinga","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"swap","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"apt","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"load","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"http","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ssh","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"users","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ping4","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0},
    {"SERVICE_NAME":"ping6","HOST_NAME":"localhost","SERVICE_CURRENT_STATE":0,"HOST_ADDRESS":"127.0.0.1","HOST_CUSTOMVARIABLE_NAME":"os","HOST_CUSTOMVARIABLE_VALUE":"Linux","HOST_CURRENT_STATE":0,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0}],
  "success":"true"
}
```

---

Time for some summary requests.

Find hosts that are "UP" and where the current state of services is not "OK".

```
http://icinga.example.com/icinga-web/web/api/service/filter[AND(HOST_CURRENT_STATE|=|0;OR(SERVICE_CURRENT_STATE|=|1;SERVICE_CURRENT_STATE|=|2))]/
columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_CURRENT_STATE|HOSTGROUP_NAME]/
order(SERVICE_CURRENT_STATE;DESC)/countColumn=SERVICE_ID/authkey=api-ps-12345/json
```

Results are good.

```json
{
  "result":[],
  "success":"true",
  "total":0
}
```

Let's create a new host that is designed to fail.

```bash
$ sudo cp /etc/icinga2/conf.d/hosts/localhost.conf /etc/icinga2/conf.d/hosts/test.conf
$ sudo vim /etc/icinga2/conf.d/hosts/test.conf
```

And add an address property inside the service definition.

```
object Host "test" {
  import "generic-host"

  address = "192.168.200.200"

  vars.os = "Linux"
  vars.sla = "24x7"
}
```

Reload Icinga2.

```bash
$ sudo service icinga2 reload
```

Wait a few minutes until Icinga2 can run its checks. I suggest logging into the Icinga Web and viewing status entries from there.

Now run the same GET request we did above.

```
http://icinga.example.com/icinga-web/web/api/service/filter[AND(HOST_CURRENT_STATE|=|0;OR(SERVICE_CURRENT_STATE|=|1;SERVICE_CURRENT_STATE|=|2))]/
columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_CURRENT_STATE|HOSTGROUP_NAME]/
order(SERVICE_CURRENT_STATE;DESC)/countColumn=SERVICE_ID/authkey=api-ps-12345/json
```

The results were not expected. We should see a host and services that are critical and down.

```json
{
  "result":[],
  "success":"true",
  "total":0
}
```

A better test is to change the HOST_CURRENT_STATE comparison operator to `>=`. 

```
http://icinga.example.com/icinga-web/web/api/service/filter[AND(HOST_CURRENT_STATE|>=|0;OR(SERVICE_CURRENT_STATE|=|1;SERVICE_CURRENT_STATE|=|2))]/
columns[SERVICE_NAME|HOST_NAME|SERVICE_CURRENT_STATE|HOST_NAME|HOST_CURRENT_STATE|HOSTGROUP_NAME]/
order(SERVICE_CURRENT_STATE;DESC)/countColumn=SERVICE_ID/authkey=api-ps-12345/json
```

Now we get expected results.

```json
{
  "result":[
    {"SERVICE_NAME":"ping4","HOST_NAME":"test","SERVICE_CURRENT_STATE":2,"HOST_CURRENT_STATE":1,"HOSTGROUP_NAME":"linux-servers","HOST_IS_PENDING":0,"SERVICE_IS_PENDING":0}],
  "success":"true",
  "total":1
}
```

The trick to successful API requests is knowing the API url structure and also parameter definitions. Unfortunately I found the Icinga-Web documentation lacking for this but thankfully this is open-source so I could go hunting for them. The next section discusses my findings.

## Parameters for Icinga Web API

My google searches didn't uncover much documentation about what parameters were possible for the Icinga-Web API. 

The Icinga2 [database definitions](https://github.com/Icinga/icinga2/blob/master/lib/db_ido_pgsql/schema/pgsql.sql) provided too much information for what I needed!  

The Icinga-Web [database definitions](https://github.com/Icinga/icinga-web/blob/master/etc/schema/pgsql.sql) did not help.

Digging around in the Icinga-Web source, I found the following columns located in "/usr/share/icinga-web/app/modules/Cronks/lib/js/Icinga/Cronks/Tackle/Information/Head.js". 

```js
columns_host: ['HOST_ID', 'HOST_OBJECT_ID', 'HOST_INSTANCE_ID', 'HOST_NAME', 'HOST_ALIAS', 'HOST_DISPLAY_NAME', 'HOST_ADDRESS', 'HOST_ADDRESS6', 'HOST_ACTIVE_CHECKS_ENABLED', 'HOST_CONFIG_TYPE', 'HOST_FLAP_DETECTION_ENABLED', 'HOST_PROCESS_PERFORMANCE_DATA', 'HOST_FRESHNESS_CHECKS_ENABLED', 'HOST_FRESHNESS_THRESHOLD', 'HOST_PASSIVE_CHECKS_ENABLED', 'HOST_EVENT_HANDLER_ENABLED', 'HOST_ACTIVE_CHECKS_ENABLED', 'HOST_RETAIN_STATUS_INFORMATION', 'HOST_RETAIN_NONSTATUS_INFORMATION', 'HOST_NOTIFICATIONS_ENABLED', 'HOST_OBSESS_OVER_HOST', 'HOST_FAILURE_PREDICTION_ENABLED', 'HOST_NOTES', 'HOST_NOTES_URL', 'HOST_ACTION_URL', 'HOST_ICON_IMAGE', 'HOST_ICON_IMAGE_ALT', 'HOST_IS_ACTIVE', 'HOST_OUTPUT', 'HOST_LONG_OUTPUT', 'HOST_PERFDATA', 'HOST_CURRENT_STATE', 'HOST_CURRENT_CHECK_ATTEMPT', 'HOST_MAX_CHECK_ATTEMPTS', 'HOST_LAST_CHECK', 'HOST_LAST_STATE_CHANGE', 'HOST_CHECK_TYPE', 'HOST_LATENCY', 'HOST_EXECUTION_TIME', 'HOST_NEXT_CHECK', 'HOST_HAS_BEEN_CHECKED', 'HOST_LAST_HARD_STATE_CHANGE', 'HOST_LAST_NOTIFICATION', 'HOST_PROCESS_PERFORMANCE_DATA', 'HOST_STATE_TYPE', 'HOST_IS_FLAPPING', 'HOST_PROBLEM_HAS_BEEN_ACKNOWLEDGED', 'HOST_SCHEDULED_DOWNTIME_DEPTH', 'HOST_SHOULD_BE_SCHEDULED', 'HOST_STATUS_UPDATE_TIME', 'HOST_CHECK_SOURCE'],

columns_service: ['SERVICE_ID', 'SERVICE_INSTANCE_ID', 'SERVICE_CONFIG_TYPE', 'SERVICE_IS_ACTIVE', 'SERVICE_OBJECT_ID', 'SERVICE_NAME', 'SERVICE_DISPLAY_NAME', 'SERVICE_NOTIFICATIONS_ENABLED', 'SERVICE_FLAP_DETECTION_ENABLED', 'SERVICE_PASSIVE_CHECKS_ENABLED', 'SERVICE_EVENT_HANDLER_ENABLED', 'SERVICE_ACTIVE_CHECKS_ENABLED', 'SERVICE_RETAIN_STATUS_INFORMATION', 'SERVICE_RETAIN_NONSTATUS_INFORMATION', 'SERVICE_OBSESS_OVER_SERVICE', 'SERVICE_FAILURE_PREDICTION_ENABLED', 'SERVICE_NOTES', 'SERVICE_NOTES_URL', 'SERVICE_ACTION_URL', 'SERVICE_ICON_IMAGE', 'SERVICE_ICON_IMAGE_ALT', 'SERVICE_OUTPUT', 'SERVICE_LONG_OUTPUT', 'SERVICE_PERFDATA', 'SERVICE_PROCESS_PERFORMANCE_DATA', 'SERVICE_CURRENT_STATE', 'SERVICE_CURRENT_CHECK_ATTEMPT', 'SERVICE_MAX_CHECK_ATTEMPTS', 'SERVICE_LAST_CHECK', 'SERVICE_LAST_STATE_CHANGE', 'SERVICE_CHECK_TYPE', 'SERVICE_LATENCY', 'SERVICE_EXECUTION_TIME', 'SERVICE_NEXT_CHECK', 'SERVICE_HAS_BEEN_CHECKED', 'SERVICE_LAST_HARD_STATE', 'SERVICE_LAST_HARD_STATE_CHANGE', 'SERVICE_LAST_NOTIFICATION', 'SERVICE_STATE_TYPE', 'SERVICE_IS_FLAPPING', 'SERVICE_PROBLEM_HAS_BEEN_ACKNOWLEDGED', 'SERVICE_SCHEDULED_DOWNTIME_DEPTH', 'SERVICE_SHOULD_BE_SCHEDULED', 'SERVICE_STATUS_UPDATE_TIME', 'SERVICE_CHECK_SOURCE'],
```

I found other variables in "sudo vim /usr/share/icinga-web/app/modules/Cronks/data/xml/to/icinga-tactical-overview-template-charts.xml".

```xml
<datasources>
    <datasource id="HOST_STATUS_SUMMARY">
        <source_type>IcingaApi</source_type>
        <target>IcingaApiConstants::TARGET_HOST_STATUS_SUMMARY_STRICT</target>
        <columns>HOST_CURRENT_STATE,HOST_STATE_COUNT</columns>
        <filter_mapping>
            <map name="CUSTOMVARIABLE_NAME">HOST_CUSTOMVARIABLE_NAME</map>
            <map name="CUSTOMVARIABLE_VALUE">HOST_CUSTOMVARIABLE_VALUE</map>
        </filter_mapping>
    </datasource>

    <datasource id="SERVICE_STATUS_SUMMARY">
        <source_type>IcingaApi</source_type>
        <target>IcingaApiConstants::TARGET_SERVICE_STATUS_SUMMARY_STRICT</target>
        <columns>SERVICE_CURRENT_STATE,SERVICE_STATE_COUNT</columns>
        <filter_mapping>
            <map name="CUSTOMVARIABLE_NAME">SERVICE_CUSTOMVARIABLE_NAME</map>
            <map name="CUSTOMVARIABLE_VALUE">SERVICE_CUSTOMVARIABLE_VALUE</map>
        </filter_mapping>
    </datasource>
</datasources>
```

And for constant definitions, I found this in "sudo vim /usr/share/icinga-web/app/modules/Web/lib/constants/IcingaConstants.class.php".

```php
interface IcingaConstants {

    // Host states
    const HOST_UP                           = 0;
    const HOST_DOWN                         = 1;
    const HOST_UNREACHABLE                  = 2;
    const HOST_PENDING                      = 99;

    // Service states
    const STATE_OK                          = 0;
    const STATE_WARNING                     = 1;
    const STATE_CRITICAL                    = 2;
    const STATE_UNKNOWN                     = 3;
    const STATE_PENDING                     = 99;

    // Logentry types
    const NSLOG_RUNTIME_ERROR               = 1;
    const NSLOG_RUNTIME_WARNING             = 2;
    const NSLOG_VERIFICATION_ERROR          = 4;
    const NSLOG_VERIFICATION_WARNING        = 8;
    const NSLOG_CONFIG_ERROR                = 16;
    const NSLOG_CONFIG_WARNING              = 32;
    const NSLOG_PROCESS_INFO                = 64;
    const NSLOG_EVENT_HANDLER               = 128;
    /* const NSLOG_NOTIFICATION             = 256 */ // (deprecated, not used)
    const NSLOG_EXTERNAL_COMMAND            = 512;
    const NSLOG_HOST_UP                     = 1024;
    const NSLOG_HOST_DOWN                   = 2048;
    const NSLOG_HOST_UNREACHABLE            = 4096;
    const NSLOG_SERVICE_OK                  = 8192;
    const NSLOG_SERVICE_UNKNOWN             = 16384;
    const NSLOG_SERVICE_WARNING             = 32768;
    const NSLOG_SERVICE_CRITICAL            = 65536;
    const NSLOG_PASSIVE_CHECK               = 131072;
    const NSLOG_INFO_MESSAGE                = 262144;
    const NSLOG_HOST_NOTIFICATION           = 524288;
    const NSLOG_SERVICE_NOTIFICATION        = 1048576;

    // Notifications reasons
    const NOTIFICATION_NORMAL               = 0;
    const NOTIFICATION_ACKNOWLEDGEMENT      = 1;
    const NOTIFICATION_FLAPPINGSTART        = 2;
    const NOTIFICATION_FLAPPINGSTOP         = 3;
    const NOTIFICATION_FLAPPINGDISABLED     = 4;
    const NOTIFICATION_DOWNTIMESTART        = 5;
    const NOTIFICATION_DOWNTIMEEND          = 6;
    const NOTIFICATION_DOWNTIMECANCELLED    = 7;
    const NOTIFICATION_CUSTOM               = 99;

    // Comments
    const HOST_COMMENT                      = 1;
    const SERVICE_COMMENT                   = 2;

    const USER_COMMENT                      = 1;
    const DOWNTIME_COMMENT                  = 2;
    const FLAPPING_COMMENT                  = 3;
    const ACKNOWLEDGEMENT_COMMENT           = 4;

    // Types
    const TYPE_HOST                         = 1;
    const TYPE_SERVICE                      = 2;
}
```