#!/bin/bash
USER_ID=${DATA_USER_ID:-1000}
GROUP_ID=${DATA_GROUP_ID:-1000}
CONFIG=${CONFIG_FILE:-"./haproxy.cfg"}

function log() { echo "### [`date +'%Y-%m-%d %T'`] $@"; }

#Create unprivileged user
groupadd -g $GROUP_ID -o haproxy
useradd --shell /usr/sbin/nologin -u $USER_ID -o -c "" -g $GROUP_ID haproxy --home /haproxy-data
chown haproxy:haproxy /haproxy-data

cd /haproxy-data

../haproxy -vv
PID_FILE="/tmp/haproxy.pid"
CHECK_CMD="../haproxy -c -f $CONFIG"
STORE_OLD_CFG="cp $CONFIG /tmp/old_haproxy.cfg"
RUN_CMD="../haproxy -D -f $CONFIG -p $PID_FILE"

$STORE_OLD_CFG
$RUN_CMD || exit $?

log "Started haproxy"
log "Listening for $CONFIG_FILE changes."

while inotifywait -q -e modify $CONFIG ; do
  if [ -f $PID_FILE ] ; then
    log "Config updated"
    diff /tmp/old_haproxy.cfg $CONFIG
    log "Checking"
    if $CHECK_CMD ; then
      log "Check OK, restarting haproxy"
      $STORE_OLD_CFG
      $RUN_CMD -sf `cat $PID_FILE`
      log "Successfuly restarted haproxy"
    else
      log "Check failed, no restart"
    fi
  else
    log "Fatal, no PID file"
    exit 999
  fi
done

