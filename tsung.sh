#!/usr/bin/env bash

UNAME=`uname`
case $UNAME in
        "Linux")
            HOST=`hostname -s 2>/dev/null`
            RET=$?
            if [ $RET != 0 ]; then
                HOST=`hostname`
                echo "WARN: hostname -s failed, use '$HOST' as hostname" > /dev/stderr
            fi
            ;;
        "SunOS") HOST=`hostname`;;
        *) HOST=`hostname -s`;;
esac

INSTALL_DIR=/usr/lib/erlang/
ERL=/bin/erl
MAIN_DIR=$HOME/.tsung
LOG_DIR=$MAIN_DIR/log
LOG_OPT="log_dir \"$LOG_DIR/\""
MON_FILE="mon_file \"tsung.log\""
VERSION=1.5.1
NAMETYPE="-sname"

PROTO_DIST=" -proto_dist inet_tcp "
LISTEN_PORT=8090
USE_PARENT_PROXY=false
PGSQL_SERVER_IP=127.0.0.1
PGSQL_SERVER_PORT=5432
NAME=tsung
CONTROLLER=tsung_controller
SMP_DISABLE=true
WARM_TIME=1
MAX_PROCESS=250000
EXCLUDE_TAG_LIST=""

TSUNGPATH=$INSTALL_DIR/lib/tsung-$VERSION/ebin
CONTROLLERPATH=$INSTALL_DIR/lib/tsung_controller-$VERSION/ebin

CONF_OPT_FILE="$HOME/.tsung/tsung.xml"
DEBUG_LEVEL=5
ERL_RSH=" -rsh ssh "
ERL_DIST_PORTS=" -kernel inet_dist_listen_min 64000 -kernel inet_dist_listen_max 65500 "
ERL_OPTS=" $ERL_DIST_PORTS -smp auto +P $MAX_PROCESS +A 16 +K true  "
COOKIE='tsung'

stop() {
    $ERL $ERL_OPTS $ERL_RSH -noshell $PROTO_DIST $NAMETYPE killer -setcookie $COOKIE -pa $TSUNGPATH -pa $CONTROLLERPATH -s tsung_controller stop_all $HOST -s init stop
}

start() {
    echo "Starting Tsung"
    $ERL $ERL_OPTS $ERL_RSH -noshell $PROTO_DIST $NAMETYPE $CONTROLLER -setcookie $COOKIE \
    -s tsung_controller \
    -pa $TSUNGPATH -pa $CONTROLLERPATH \
    -tsung_controller smp_disable $SMP_DISABLE \
    -tsung_controller debug_level $DEBUG_LEVEL \
    -tsung_controller warm_time $WARM_TIME \
    -tsung_controller exclude_tag \"$EXCLUDE_TAG_LIST\" \
    -tsung_controller config_file \"$CONF_OPT_FILE\" -tsung_controller $LOG_OPT -tsung_controller $MON_FILE
}

debug() {
    $ERL $ERL_OPTS $ERL_RSH $NAMETYPE $CONTROLLER $PROTO_DIST -setcookie $COOKIE  \
     -s tsung_controller \
     -pa $TSUNGPATH -pa $CONTROLLERPATH \
     -tsung_controller warm_time $WARM_TIME \
     -tsung_controller config_file \"$CONF_OPT_FILE\" \
     -tsung_controller exclude_tag \"$EXCLUDE_TAG_LIST\" \
     -tsung_controller $LOG_OPT -tsung_controller $MON_FILE
}

version() {
    echo "Tsung version $VERSION"
    exit 0
}

checkconfig() {
    if [ ! -e $CONF_OPT_FILE ] && [ $CONF_OPT_FILE != "-" ]
    then
        echo "Config file $CONF_OPT_FILE doesn't exist, aborting !"
        exit 1
    fi
}

maindir() {
    if [ ! -d $MAIN_DIR ]
    then
        echo "Creating local Tsung directory $MAIN_DIR"
        mkdir $MAIN_DIR
    fi
}

logdir() {
        if [ ! -d $LOG_DIR ]
        then
                echo "Creating Tsung log directory $LOG_DIR"
                mkdir $LOG_DIR
        fi
}

status() {
    SNAME=tsung_status_$RANDOM
    $ERL -noshell $NAMETYPE $SNAME -setcookie $COOKIE -pa $TSUNGPATH -pa $CONTROLLERPATH -s tsung_controller status $HOST -s init stop
}

checkrunning_controller() {
    RES=`status`
    if [ "$RES" != "Tsung is not started" ]; then
        echo "Tsung is already running, exit."
        exit 1
    fi
}

usage() {
    prog=`basename $0`
    echo "Usage: $prog <options> start|stop|debug|status"
    echo "Options:"
    echo "    -f <file>     set configuration file (default is ~/.tsung/tsung.xml)"
    echo "                   (use - for standard input)"
    echo "    -l <logdir>   set log directory where YYYYMMDD-HHMM dirs are created (default is ~/.tsung/log/) "
    echo "    -i <id>       set controller id (default is empty)"
    echo "    -r <command>  set remote connector (default is ssh)"
    echo "    -s            enable erlang smp on client nodes"
    echo "    -p <max>      set maximum erlang processes per vm (default is 250000)"
    echo "    -m <file>     write monitoring output on this file (default is tsung.log)"
    echo "                   (use - for standard output)"
    echo "    -F            use long names (FQDN) for erlang nodes"
    echo "    -w            warmup delay (default is 1 sec)"
    echo "    -v            print version information and exit"
    echo "    -6            use IPv6 for Tsung internal communications"
    echo "    -x <tags>     list of requests tag to be excluded from the run (separated by comma)"
    echo "    -h            display this help and exit"
    exit
}

while getopts "6vhf:l:d:r:i:Fsw:m:p:x:" Option
do
    case $Option in
        f) CONF_OPT_FILE=$OPTARG;;
        l) # must add absolute path
            echo "$OPTARG" | grep -q "^/"
            RES=$?
            if [ "$RES" == 0 ]; then
                LOG_OPT="log_dir \"$OPTARG/\" "
            else
                LOG_OPT="log_dir \"$PWD/$OPTARG/\" "
            fi
            ;;
        m) MON_FILE="mon_file \"$OPTARG\"";;
        d) DEBUG_LEVEL=$OPTARG;;
        p) MAX_PROCESS=$OPTARG;;
        r) ERL_RSH=" -rsh $OPTARG ";;
        6) PROTO_DIST=" -proto_dist inet6_tcp ";;
        F) NAMETYPE="-name";;
        w) WARM_TIME=$OPTARG;;
        s) SMP_DISABLE="false";;
        v) version;;
        i) ID=$OPTARG
           COOKIE=$COOKIE"_"$ID
           CONTROLLER=$CONTROLLER"_"$ID
           ;;
        x) EXCLUDE_TAG_LIST=$OPTARG;;
        h) usage;;
        *) usage ;;
    esac
done
shift $(($OPTIND - 1))

case $1 in
    start)
        checkconfig
        maindir
        logdir
        start
        ;;
    debug)
        checkconfig
        maindir
        logdir
        debug
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    *)
        usage $0
        ;;
esac
