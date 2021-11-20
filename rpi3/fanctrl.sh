#!/bin/sh
# Author Sergej Stepanov <sistux@sistux.de>
# the work done to make a fan control depends on cpu-temperatur
# there are many python scripts found, but the shell-script for me is much pretty
# it checks every 5 seconds the cpu-temperature
# if it's higher than threshold it starts the fan
#

TEMPTHRESHOLDVAL=38 # temperature
FANGPIO=4
CHECKDELAY=5

# prepare the gpio
GPIODIR="/sys/class/gpio"
FANGPIOPATH=$GPIODIR"/gpio"$FANGPIO

echo $GPIODIR
echo $FANGPIOPATH

if [ ! -e "$FANGPIOPATH/value" ];then
    echo $FANGPIO > $GPIODIR/export
    sleep 1
    if [ ! -e "$FANGPIOPATH/direction" ];then
	echo -e "[ERROR] GPIO '$FANGPIO' cann't be exported"
	exit 1
    else
	ls -l $GPIODIR

	echo
	ls -l $FANGPIOPATH
	echo "testt echo out > $FANGPIOPATH"
	#ls -l $FANGPIOPATH/direction
	#ls -l $FANGPIOPATH/value
	echo out>$FANGPIOPATH/direction
	echo 0>$FANGPIOPATH/value
    fi
fi

while true
do
    GPIOSTATE=`cat $FANGPIOPATH/value`
    CPUTEMP=`vcgencmd measure_temp | cut -c6,7`
    echo T:$CPUTEMP GPIO:$GPIOSTATE
    if [ $CPUTEMP -ge $TEMPTHRESHOLDVAL ] && [ $GPIOSTATE -eq 0 ]
    then
	echo "1" > $FANGPIOPATH/value
    elif [ $CPUTEMP -le $TEMPTHRESHOLDVAL ] && [ $GPIOSTATE -eq 1 ]
    then
	echo "0" > $FANGPIOPATH/value
    fi

    sleep $CHECKDELAY
done
echo "Exit. Normally it should not happens"
exit 2
