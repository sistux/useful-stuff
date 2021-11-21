#!/bin/sh
# Author Sergej Stepanov <sistux@sistux.de>
# the work done to make a fan control depends on cpu-temperatur
# there are many python scripts found, but the shell-script for me is much pretty
# it checks every 5 seconds the cpu-temperature
# if it's higher than threshold it starts the fan
#

TEMPTHRESHOLDVAL=40 # temperature
TEMPHISTER=3 # histeresis
FANGPIO=4
CHECKDELAY=5
FANGPIOPIDFILE=/var/run/fanctrl.pid
GPIODIR="/sys/class/gpio"
FANGPIOPATH=$GPIODIR"/gpio"$FANGPIO

prepare_gpio()
{
    if [ ! -e "$FANGPIOPATH/value" ];then
	echo $FANGPIO > $GPIODIR/export
	sleep 1 # the system needs some time
	if [ ! -e "$FANGPIOPATH/direction" ];then
	    echo -e "[ERROR] GPIO '$FANGPIO' cann't be exported"
	    exit 1
	else
	    echo out>$FANGPIOPATH/direction
	    echo 0>$FANGPIOPATH/value
	fi
    fi
}

cleanup_gpio()
{
    if [ -e "$FANGPIOPATH/value" ];then
	echo $FANGPIO > $GPIODIR/unexport
    fi
}

runasdaemon()
{
    # echo "runasdaemon"
    while true
    do
	GPIOSTATE=`cat $FANGPIOPATH/value`
	CPUTEMP=`vcgencmd measure_temp | cut -c6,7`
	if [ $CPUTEMP -ge $TEMPTHRESHOLDVAL ] && [ $GPIOSTATE -eq 0 ]
	then
	    # echo Enable: T:$CPUTEMP GPIO:$GPIOSTATE
	    echo "1" > $FANGPIOPATH/value
	elif [ $CPUTEMP -le `expr $TEMPTHRESHOLDVAL - $TEMPHISTER` ] && [ $GPIOSTATE -eq 1 ]
	then
	    # echo Disable: T:$CPUTEMP GPIO:$GPIOSTATE
	    echo "0" > $FANGPIOPATH/value
	fi

	sleep $CHECKDELAY
	# echo "runasdaemon loop"
    done
    echo "Exit. Normally it should not happens"
    exit 2
}

case $1 in
    start )
	prepare_gpio
	$0 runit &
	echo $! > $FANGPIOPIDFILE
	;;
    stop )
	if [ -e $FANGPIOPIDFILE ];then
	    kill `cat $FANGPIOPIDFILE`
	    rm $FANGPIOPIDFILE
	fi
	cleanup_gpio
	;;
    restart )
	cleanup_gpio
	;;
    status)
	# code to check status of app comes here
	# example: status program_name
	if [ -e $FANGPIOPIDFILE ];then
	    echo "PID FanCtrl Process:`cat $FANGPIOPIDFILE`"
	else
	    echo "No PidFile \"$FANGPIOPIDFILE\" was found!"
	fi
	GPIOVALUE=`if [ -e $FANGPIOPATH/value ];then cat $FANGPIOPATH/value;else echo "nogpio";fi`
	CPUTEMP=`vcgencmd measure_temp`
	echo "Info:cpu-temp:$CPUTEMP,gpio:$GPIOVALUE"
	;;
    runit )
	runasdaemon
	;;
    *)
	echo "Usage: $0 {start|stop|status|restart}"
esac

exit 0
