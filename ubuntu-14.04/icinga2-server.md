> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Icinga2 central server using nginx and postgresql

Let's be very clear. There are two components to monitoring. 

* Central Server: we are using icinga 2 for the core and icinga web for the GUI (version 2 of the web interface is still under "heavy development")
* Clients: Any server we want to monitor will have Nagios Remote Plugin Executor (NRPE)

The examples below cover setting up the **Central Server**. For setting up the **Client** to communicate with Icinga, see [this example](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nagios-npre-client.md).

They assume a core Ubuntu 14.04 installation with a fully-qualified-domain-name of 'icinga.example.com'. The server name should be configured in DNS and accessible via ssh.

This example will be covering the following:

* Install Icinga2
* Install Postgresql and let Icinga2 use it for storage
* Install Nginx, PHP and Postgres dependencies
* Install Icinga-Web (not Icinga-Classic nor Icinga-Web2)
* Run Icinga-Web using Nginx
* Test

I chose Icinga instead of Nagios because I wanted to integrate with Postgres. Also the web-interface is slick and, since Icinga is a fork of Nagios, any plugins developed for Nagios will work in Icinga.

> Note: The examples were compiled chiefly from these sources: [Icinga 2 Getting Started Documentation](http://docs.icinga.org/icinga2/latest/doc/module/icinga2/chapter/getting-started#installing-requirements), GitHub [Install Readme](https://github.com/Icinga/icinga-web/blob/master/doc/INSTALL) for Icinga-Web and [Icincga-Web From Scratch](http://docs.icinga.org/latest/en/icinga-web-scratch.html).

## Install Icinga2

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

## Install Postgresql and let Icinga2 use it for storage

Install postgresql.

```bash
sudo apt-get install postgresql
```

Install the icinga2 module that communicates with postgresql.

```bash
sudo apt-get install icinga2-ido-pgsql

# WIZARD 1 --> Choose YES
# WIZARD 2 --> Choose NO (we'll set this manually)
```

Login to postgres.

```bash
sudo -u postgres psql
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
sudo -u postgres psql -c "CREATE ROLE icinga WITH LOGIN PASSWORD 'icinga'";
sudo -u postgres createdb -O icinga -E UTF8 icinga
```

---

Add the icinga user with md5 authentication to `pg_hba.conf`.

```bash
sudo vim /etc/postgresql/*/main/pg_hba.conf
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
sudo service postgresql restart
```

---

Import into the `icinga` database the schema found in `/usr/share/icinga2-ido-pgsql/schema`.

```bash 
psql -U icinga -d icinga < /usr/share/icinga2-ido-pgsql/schema/pgsql.sql 
```

Update ido-pgsql.conf.

```bash
sudo vim /etc/icinga2/features-available/ido-pgsql.conf 
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

Enable the `ido-pgsql` modules.

```bash
sudo icinga2-enable-feature ido-pgsql
```

Since we are enabling features, let's also add `command`. This allows an external command pipe be accessible for web interfaces and Icinga addons to communicate with Icinga2.

```bash
sudo icinga2-enable-feature command
```

Restart icinga2.

```bash
sudo service icinga2 restart
```

## Install Nginx, PHP and Postgres dependencies

Install nginx, php and postgres dependencies.

```bash
sudo apt-get install nginx php5-fpm php-apc php5-pgsql php5-cli php-pear php5-xmlrpc php5-xsl php-soap php5-gd php5-ldap php5-json
```

By default nginx launches a web page that can now be accessed by your client browser. Assuming you have DNS pointed to `icinga.example.com`, bring up in a web browser:

```
http://icinga.example.com
```

A little maintenance. Follow [this guide](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx-proxy.md) to setup nginx as a proxy but feel free to leave out the `myapp` configuration.

Let's create a new nginx site that will test our php installation. 

```bash
sudo vim /etc/nginx/sites-available/test-php
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
sudo mkdir -p /var/wwww/test-php
sudo vim /var/www/test-php/index.php
```

Paste this into `index.php`.

```php
<?php
  phpinfo( );
?>
```

---

Disable the `default` nginx site.

```bash
sudo nginx_modsite -d default
```

Enable `test-php`.

```bash
sudo nginx_modsite -e test-php
```

Restart nginx.

```bash
sudo service nginx restart
```

Reload your browser. You should now see the information passed back from `phpinfo()`.

```
http://icinga.example.com
```

## Install Icinga-Web

We are going to install Icinga-Web, which is not Icinga-Classic nor Icinga-Web2. Icinga-Web is compatible with both Icinga and Icinga2 modules. Many of the Debian/Ubuntu-related tutorials on the internet are for Icinga-Classic. This example is not Icinga-Classic; it is for Icinga-Web, which is Icinga's current "flagship" interface. Please see [this page](https://www.icinga.org/icinga/screenshots/) to begin investigating differences.

In order to get Icinga-Web to better behave with nginx commands to rewrite and alias files, we are going build and install Icinga-Web in one site and then point the Nginx website to it. When finished, it will look like this:

* ~/icinga-web: This is the unpackaged source file or clone from GitHub. We configure the installation here. `make` will install the installation to a folder we specify.
* ~/prod/icinga-web: This is the directory in which `make` will install icinga-web. If we were running Apache, an Apache configuration file would have already been pre-generated and would point to this directory. But we are using Nginx, so add a 3rd directory which will symlink back to this one.
* /var/www/icinga: This is the root of the Nginx directory that gets symlinked back to icinga-web. 

This example uses release v1.11.2. See [this website](https://github.com/Icinga/icinga-web/releases) for the latest production releases.

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

Dive into postgres and create the icinga_web role and database.  Change the default PASSWORD of `icinga_web` to something more secure.

```
sudo -u postgres psql -c "CREATE ROLE icinga_web WITH LOGIN PASSWORD 'icinga_web'";
sudo -u postgres createdb -O icinga_web -E UTF8 icinga_web
```

Give the user `icinga_web` trusted authentication rights to start-stop postgresql by adding the following  to `pg_hba.conf`.

First open the file.

```bash
sudo vim /etc/postgresql/9.3/main/pg_hba.conf
```

Just after the `icinga` entries added earlier, include:

```
#icinga_web
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
psql -U icinga_web -d icinga_web < etc/schema/pgsql.sql 
```

Configure the site. You will need to replace `/PATH/TO/PROD/DIRECTORY/icinga-web` with your mapping. For example, `/PATH/TO/PROD/DIRECTORY/icinga-web` would be mapped to `~/prod/icinga-web`. 

```
./configure \
          --prefix=/PATH/TO/PROD/DIRECTORY/icinga-web \
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

## Run Icinga-Web using Nginx

> Credits: A huge **THANK YOU** goes to "Rancor" [on this thread](http://www.monitoring-portal.org/wbb/index.php?page=Thread&threadID=29035), who posted a working solution for Nginx and Icinga-Web.

Create a new nginx site for `icinga.example.com`. 

```bash
sudo vim /etc/nginx/sites-available/icinga.example.com
```

Copy the following into the editor. In three places, you will need to replace `/PATH/TO/PROD/DIRECTORY/icinga-web` with your mapping. For example, `/PATH/TO/PROD/DIRECTORY/icinga-web` would be mapped to `~/prod/icinga-web`. 

```nginx
#VERSION: "icinga.example.com"
server {
        listen      10.10.11.6:80;
        server_name icinga.apples.lan;
        access_log  /var/log/nginx/icinga.apples.lan.access.log  main;
        error_log   /var/log/nginx/icinga.apples.lan.error.log;
        root        /var/www/icinga;
        index index.php index.html index.htm;

        location = / {
                rewrite ^/$ /icinga-web permanent;
        }

        location /icinga-web/modules/([A-Za-z0-9]*)/resources/images/([A-Za-z_\-0-9]*\.(png|gif|jpg))$ {
                alias /PATH/TO/PROD/DIRECTORY/icinga-web/app/modules/$1/pub/images/$2;
        }

        location /icinga-web/modules/([A-Za-z0-9]*)/resources/styles/([A-Za-z0-9]*\.css)$ {
                alias /PATH/TO/PROD/DIRECTORY/icinga-web/app/modules/$1/pub/styles/$2;
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
                fastcgi_param SCRIPT_FILENAME /PATH/TO/PROD/DIRECTORY/icinga-web/pub/index.php;
        }
}
```

Create a symlink from the `lib` folder to the javascript folder inside`/PATH/TO/PROD/DIRECTORY`.

```bash
sudo ln -s /PATH/TO/PROD/DIRECTORY/icinga-web/lib /PATH/TO/PROD/DIRECTORY/icinga-web/pub/js
```

Create the root web folder that nginx is pointed at.

```bash
sudo mkdir -p /var/www/icinga
```

Create a symlink from the nginx root to the `published` production web folder.

```bash
sudo ln -s /PATH/TO/PROD/DIRECTORY/icinga-web/pub /var/www/icinga/icinga-web
```

Change permissions.

```bash
sudo chown -R www-data:www-data /var/www/icinga/icinga-web
sudo chown -R www-data:www-data /PATH/TO/PROD/DIRECTORY/icinga-web
```

Disable `test-php`.

```bash
sudo nginx_modsite -d test-php
```

Enable `test-php`.

```bash
sudo nginx_modsite -e icinga.example.com
```

Restart nginx.

```bash
sudo service nginx restart
```

---

Refresh your web-browser that points to `icinga.example.com`. You will be redirected to the following:

```
http://icinga.example.com/icinga-web/
```

The default Icinga-Web user and password are the following:

* Default user: `root`
* Default password: `password`

You should be greated with the following screenshot with zero errors!

![Results of myapp in browser](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/nginx/myapp-hello-world.png)


## Test

Yes, the website is visible. But how to configure a host site? 

configure host (video??? nginx or domain specific)


NEXT: config NPRE module

