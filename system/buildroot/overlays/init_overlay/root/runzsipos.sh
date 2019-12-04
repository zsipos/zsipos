#!/bin/sh
#
# zsiposapp    Start zsipos
#

cd /root

LASTERR=/root/last_error.txt
FIFO=/tmp/zsiposfifo
PIDFILEZIPPOS=/var/run/zsipos.pid
PIDFILERUN=/var/run/runzsipos.pid

get_pidfile() {
    if [ "$1" = "runzsipos" ]; then
        PIDFILE=$PIDFILERUN
        KILL=kill
    elif [ "$1" = "zsipos" ]; then
        PIDFILE=$PIDFILEZIPPOS
        KILL="kill -9"
    else
        echo "running: $1 unknown"
        exit 1
    fi
}

get_pid() {
    get_pidfile $1
    if [ -f $PIDFILE ]; then
        PID=$(sed 's/ //g' $PIDFILE)
    else
        if [ "$1" = "zsipos" ]; then
            PIDLIST=`pidof python`
            PID=`for i in $PIDLIST; do ps -p $i -o args | grep zsipos.py && echo $i; done`
        fi
    fi
}

out() {
    echo `date`: "$@"
    echo `date`: "$@" >$FIFO 
}

running() {
    get_pid $1

    if [ -n "$PID" ]; then
        kill -0 $PID 2>/dev/null && echo y || rm -f $PIDFILE
    fi
}

testexit() {
    RET=$1
    if [ $RET -eq 0 ]; then
        out zsipos finished
    else
        out "zipos exited with error $RET"
        if [ -f $LASTERR ]; then
            echo "lasterror:" >$FIFO
            cat $LASTERR >$FIFO
        else
            echo "nohup.out:..........." >$FIFO
            tail -30 /root/nohup.out >$FIFO
            echo "........... end nohup.out" >$FIFO
        fi
        if [ -f core ]; then
            echo "!!!!!!!!!!!!!!!!!!!!!!!" >$FIFO
            echo "!!!!!!!!!!!!!!!!!!!!!!!" >$FIFO
            out "Oops, core dumped"
            echo "!!!!!!!!!!!!!!!!!!!!!!!" >$FIFO
            echo "!!!!!!!!!!!!!!!!!!!!!!!" >$FIFO
            out "restarting in a minute"
            sleep 60
            # savelog NOT compress (takes too long)
            /root/savelog -l -d -r archive core
        elif [ $RET -eq 2 -o $RET -eq 99 ]; then
            out "unrecoverable error in gui, exit"
            exit $RET
        elif [ $RET -eq 1 ]; then
            out "configuration error occurred, reconfigure"
        else
            out "restarting in 10 seconds"
            sleep 10
        fi
    fi
}

#
# main
#

RUNNING=$(running runzsipos)
if [ -n "$RUNNING" ]; then
    echo "runzipos.sh is running"
    exit 0
fi

echo $$ >$PIDFILERUN

RUNNING=$(running zsipos)
if [ -n "$RUNNING" ]; then
    echo "zsipos is running, killed"
    get_pid zsipos
    $KILL $PID
fi

RUNCMD="/usr/bin/python zsipos/zsipos.py --logfile zsipos.log"
CFGCMD="/usr/bin/python zsipos/zsipos.py --cfg-gui"

while :
do
    # keep 7 files rotated, not zipped
    /root/savelog -n -l -d -r archive zsipos.log
    out $RUNCMD
    $RUNCMD
    testexit $?
    #out ausgetestet
    if [ $RET -eq 1 ]; then
      out $CFGCMD
      $CFGCMD
      testexit $?
    fi
done
