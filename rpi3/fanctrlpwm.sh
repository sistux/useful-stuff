#!/bin/sh
# Author Sergej Stepanov <sistux@sistux.de>
# the work done to make a fan control depends on cpu-temperatur
# there are many python scripts found, but the shell-script was just simply
# it checks every 5 seconds the cpu-temperature
# it use hw-pwm-driver on GPIO12
# on https://pinout.xyz and other resources could be found how the hw-pwm would be andbled
# * in the /boot/config -> dtoverlay=pwm,pin=12,func=4
#

TEMPMAX=80
TEMPTHRESHOLDVAL=50 # temperature
TEMPHISTER=3 # histeresis
FANGPIO=0 # dtoverlay config
CHECKDELAY=5
FANGPIOPIDFILE=/var/run/fanctrlpwm.pid
PWMDIR="/sys/class/pwm/pwmchip0"
FANPWMPATH=$PWMDIR/pwm0
FANPWMPERIOD=period
FANPWMDUTYCYCLE=duty_cycle
FANPWMENABLE=enable
FANPWMFREQ=25
PERIODNANOSEC=`expr 1000000000 / $FANPWMFREQ`
DUTYNANOSEC=`expr 1000000000 / $FANPWMFREQ`

prepare_gpio()
{
    if [ ! -e "$FANPWMPATH" ];then
	echo 0 > $PWMDIR/export
	sleep 1 # the system needs some time
	if [ ! -e "$FANPWMPATH" ];then
	    echo -e "[ERROR] PWM on GPI12 cann't be enabled"
	    exit 1
	else
	    echo $PERIODNANOSEC>$FANPWMPATH/$FANPWMPERIOD
	    echo $DUTYNANOSEC>$FANPWMPATH/$FANPWMDUTYCYCLE
	fi
    fi
}

cleanup_gpio()
{
    if [ -e "$FANPWMPATH" ];then
	echo 0 > $FANPWMPATH/enable
	echo 0 > $PWMDIR/unexport
    fi
}

TEMPPERCENT=`expr \( $TEMPMAX - $TEMPTHRESHOLDVAL \) \* 1000000 / \( 100 - 30 \)`
runasdaemon()
{
    # echo "runasdaemon"
    while true
    do
	#GPIOSTATE=`cat $FANGPIOPATH/value`
	CPUTEMP=`vcgencmd measure_temp | cut -c6,7`
	#echo $CPUTEMP
	if [ $CPUTEMP -le $TEMPTHRESHOLDVAL ]
	then
	    DUTYNANOSEC=0
	    echo 0 > $FANPWMPATH/enable
	elif [ $CPUTEMP -ge $TEMPMAX ]
	then
	    DUTYNANOSEC=$PERIODNANOSEC
	    echo $DUTYNANOSEC > $FANPWMPATH/$FANPWMDUTYCYCLE
	    echo 1 > $FANPWMPATH/enable
	else
	    DUTYNANOSEC=`expr \( $TEMPMAX - $TEMPTHRESHOLDVAL \) \* $TEMPPERCENT `
	    echo $DUTYNANOSEC > $FANPWMPATH/$FANPWMDUTYCYCLE
	    echo 1 > $FANPWMPATH/enable
	fi
	#echo $DUTYNANOSEC

	sleep $CHECKDELAY
	# echo "runasdaemon loop"
    done
    echo "Exit. Normally it should not happens"
    exit 2
}

case $1 in
    start )
	$0 runit &
	echo $! > $FANGPIOPIDFILE
	sleep 1
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
	CPUTEMP=`vcgencmd measure_temp`
	echo "Info:cpu-temp:$CPUTEMP,"
	;;
    runit )
	prepare_gpio
	runasdaemon
	cleanup_gpio
	;;
    *)
	echo "Usage: $0 {start|stop|status|restart}"
esac

exit 0
