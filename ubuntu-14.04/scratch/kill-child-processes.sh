#!/bin/sh

### BEGIN INIT INFO
# Provides:	  xyz-server
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts xyz-server
# Description:       starts xyz-server using a specific version of nvm
### END INIT INFO

. /lib/init/vars.sh
. /lib/lsb/init-functions

# Actually this doesn't work on a child process
#start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pid 22096
# It's better to use
#pkill -TERM -P $PARENT-PID

CONFIGNAME="xyz-server"
DESC="starts xyz-server using a specific version of nvm"

PID="/var/run/$CONFIGNAME.pid"

if [ -f $PID ];
then
	echo "File $PID exists"

	read PPID <$PID

	echo $PPID

	COUNT=0

	for i in `ps -ef| awk '$3 == '${PPID}' { print $2 }'`
	do
		echo killing $i
		COUNT=$((COUNT+1))
		echo $COUNT
		#kill -9 $i
	done

else
   echo "File $PID does not exists"
fi
