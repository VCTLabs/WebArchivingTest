#!/bin/bash
### BEGIN INIT INFO
# Provides:          heritrix
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# X-Interactive:     true
# Short-Description: start/stop heritrix web crawler
### END INIT INFO

##########################################################################################
#
# Heritrix Init Script (heritrix_init_d.sh) (c) by Jack Szwergold
#
# Heritrix Init Script is licensed under a
# Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
#
# You should have received a copy of the license along with this
# work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>. 
#
# w: http://www.preworn.com
# e: me@preworn.com
#
# Created: 2014-08-11, js
# Version: 2014-08-11, js: creation
#          2014-08-11, js: development
#
##########################################################################################

# Get defaults from file
PATH=/bin:/usr/bin:/sbin:/usr/sbin
NAME=heritrix
DESC="Heritrix web crawler"
DEFAULT=/etc/default/$NAME

# Set the networking stuff.
HERITRIX_USER="vagrant"
HERITRIX_CREDENTIALS="admin:password"
HERITRIX_HOME="/opt/heritrix-3.2.0"
JAVA_HOME='/usr/lib/jvm/java-1.7.0-openjdk-i386'
IP_ADDRESS="/"
PORT=8443

# overwrite settings from default file
if [ -f "$DEFAULT" ]; then
  . "$DEFAULT"
fi

export PATH=$JAVA_HOME/bin:$HERITRIX_HOME/bin:$PATH

# Non-configurable stuff below
HERITRIX_BINARY="heritrix"
JAVA_APP_NAME="Heritrix"
HERITRIX_BINARY_FULL="bin/$HERITRIX_BINARY"
HERITRIX_BINARY_OPTS="-b $IP_ADDRESS -p $PORT -a $HERITRIX_CREDENTIALS $HERITRIX_ADDITIONAL_OPTS"

# Set the init.d specific stuff.
PID_FILENAME="/var/run/$HERITRIX_BINARY.pid"
INITD_SCRIPTNAME="/etc/init.d/$HERITRIX_BINARY"
# INDENT_SPACING=$(tput cols)
INDENT_SPACING=50

case "$1" in

start)

  if [ -f "$PID_FILENAME" ]; then
    PID=`cat $PID_FILENAME`
    PID_CHECK=`ps axf | grep ${PID} | grep -v grep`
  else
    PID_CHECK=$(awk -vnode="$JAVA_APP_NAME" '$2 ~ node { print $1 }' <(su "$HERITRIX_USER" -c "jps -l"))
  fi

  if [ ! -f "$PID_FILENAME" ] && [ -z "$PID_CHECK" ]; then
    printf "%-${INDENT_SPACING}s" "Starting $HERITRIX_BINARY..."
    su "$HERITRIX_USER" -c "cd $HERITRIX_HOME && $HERITRIX_BINARY_FULL $HERITRIX_BINARY_OPTS > /dev/null 2>&1"
    PID=$(awk -vnode="$JAVA_APP_NAME" '$2 ~ node { print $1 }' <(su "$HERITRIX_USER" -c "jps -l"))
    # echo "Saving PID $PID to $PID_FILENAME."
    if [ -z "$PID" ]; then
      printf "Fail\n"
    else
      echo "$PID" > "$PID_FILENAME"
      if [ -f "$PID_FILENAME" ]; then
        printf "[ OK ]\n"
      fi
    fi
  else
    printf "$HERITRIX_BINARY (pid $PID) already running.\n"
  fi

;;

status)

  printf "%-${INDENT_SPACING}s" "Checking $HERITRIX_BINARY..."
  if [ -f "$PID_FILENAME" ]; then
    PID=`cat $PID_FILENAME`
    PID_CHECK=`ps axf | grep ${PID} | grep -v grep`
    if [ -z "$PID_CHECK" ]; then
      printf "Process not running but pidfile exists.\n"
    else
      printf "$HERITRIX_BINARY (pid $PID) running.\n"
    fi
  else
    printf "$HERITRIX_BINARY not running.\n"
  fi

;;

stop)

  printf "%-${INDENT_SPACING}s" "Stopping $HERITRIX_BINARY..."
  if [ -f "$PID_FILENAME" ]; then
    PID=`cat $PID_FILENAME`
    # PID_CHECK=$(awk -vnode="$JAVA_APP_NAME" '$2 ~ node { print $1 }' <(jps -l))
    PID_CHECK=`ps axf | grep ${PID} | grep -v grep`
    if [ ! -z "$PID_CHECK" ]; then
      kill "$PID"
    fi
    printf "[ OK ]\n"
    rm -f "$PID_FILENAME"
  else
    printf "$HERITRIX_BINARY pidfile ($PID_FILENAME) not found.\n"
  fi

;;

# restart)
#   # $0 stop & STOP_PID=(`jobs -l | awk '{print $2}'`);
#   # wait ${STOP_PID}
#   $0 stop
#   $0 start
# ;;

*)
  # echo "Usage: $0 {status|start|stop|restart}"
  echo "Usage: $0 {status|start|stop}"
  exit 1
esac
