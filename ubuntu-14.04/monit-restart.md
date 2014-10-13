> Back to [Table of Contents](https://github.com/jpfluger/examples)

# Restart Crashed Apps with Monit

> Note: Much of this example comes from the [tutorial](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-monit) by Digital Ocean, [node-monit](https://github.com/nicokaiser/node-monit) by Nico Kaiser.

## Installation

Install using `apt-get`.

```bash
sudo apt-get install monit
```

The config file is called `monitrc` and it is located in `/etc/monit`. Let's open this file.

```bash
sudo vim /etc/monit/monitrc
```

Uncomment in the first couple lines for the httpd service. This allows monit to report status and summaries.

```bash
set httpd port 2812 and
    use address localhost  # only accept connection from localhost
    allow localhost        # allow localhost to connect to the server and
```

Restart monit.  Always use the `service` method to start, stop or restart monit instead of `sudo monit stop all` or `sudo monit start all`. You will get errors for the latter commands.

```bash
sudo service monit restart
```

View status.

```bash
sudo monit status

#OUTPUT
The Monit daemon 5.6 uptime: 3m 

System 'svr1'
  status                            Running
  monitoring status                 Monitored
  load average                      [0.52] [0.48] [0.46]
  cpu                               2.3%us 0.3%sy 0.0%wa
  memory usage                      3687284 kB [11.2%]
  swap usage                        0 kB [0.0%]
  data collected                    Sun, 12 Oct 2014 21:18:30

```

View summary.

```bash
sudo monit summary

#OUTPUT
The Monit daemon 5.6 uptime: 4m 

System 'svr1'              Running
```

The monit log file can be found in `/var/log/monit.log`.

## View using web

Open a browser and navigate to [http://localhost:2812](http://localhost:2812/). You should see something like the following:

![Results of monit after first startup](https://github.com/jpfluger/examples/blob/master/ubuntu-14.04/monit/monit-after-install.png)

## Configuration examples

Let's first create the monit for `nginx`.

```bash
sudo vim /etc/monit/conf.d/nginx
```

Edit like this:

```bash
check process nginx with pidfile /var/run/nginx.pid
    start program = "/etc/init.d/nginx start"
    stop program = "/etc/init.d/nginx stop"
```

Now a monit for our `node-app` process.

```bash
check node-app with pidfile /var/run/node-app.pid
start program = "/etc/init.d/node-app start"
stop program = "/etc/init.d/node-app stop"

if failed port 1337 protocol HTTP request / with timeout 10 seconds then restart
if 3 restarts within 5 cycles then timeout
```

Check the configurations.

```bash
```

Restart monit.

```bash
sudo service monit restart
```

Show a summary of what is being monitored by command (see below) or refresh your monit web page to view the new items monitored.

```bash
sudo monit summary

#OUTPUT
The Monit daemon 5.6 uptime: 8m 

Process 'node-app'         Running
Process 'nginx'            Running
System 'svr1'              Not monitored
```

> Note: See [monit wiki](http://mmonit.com/wiki/Monit/ConfigurationExamples#postgresql) for a list of configurations to common services.

## Testing

Stop one of the monitored services, like nginx or node-app and wait for monit to restart it.

Stop nginx.

```bash
sudo service nginx stop
```

View the end of the monit log for when it restarted nginx.

```bash
tail -n 100 /var/log/monit.log | less

#OUTPUT
[CDT Oct 12 23:32:29] error    : 'nginx' process is not running
[CDT Oct 12 23:32:29] info     : 'nginx' trying to restart
[CDT Oct 12 23:32:29] info     : 'nginx' start: /etc/init.d/nginx
[CDT Oct 12 23:34:29] info     : 'nginx' process is running with pid 1058
```