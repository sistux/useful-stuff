#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <pigpio.h>
#include <string>
#include <iostream>
#include <fstream>
#include <sstream>
#include <math.h>

int iPWMgpio = 12;
int iPWMfreq = 25;
int iStartStep = 1000000;
int iDownStep = 100000;

std::string c_strCpuTempFName = "/sys/class/thermal/thermal_zone0/temp";

double getPICpuTemp(std::string strCpuTempFName = "/sys/class/thermal/thermal_zone0/temp")
{
	std::ifstream piCpuTempFile;
	double dPICpuTemp = 0.0;
	std::stringstream sstrDataBuffer;
	piCpuTempFile.open(strCpuTempFName);
	sstrDataBuffer << piCpuTempFile.rdbuf();
	piCpuTempFile.close();
	sstrDataBuffer >> dPICpuTemp;
	dPICpuTemp = dPICpuTemp / 1000.0; // convert float value to degree
	return dPICpuTemp;
}

double dLowTemp = 45.0;
double dMaxTemp = 80.0;
double dLowFanSpeed = 30.0;

int main(int argc, char *argv[])
{
	if (gpioInitialise() < 0) {
		std::cout << "[ERROR] Exit! Could not initialise the pigpio-lib."
			  << std::endl;
		return 1;
	}
	int iCurFanStep = 0;
	double dPICpuTemp = getPICpuTemp();
	std::cout << "[INFO] start PWM fan control on gpio "
		  << iPWMgpio << " with base freq " << iPWMfreq << "."
		  << std::endl
		  << "Current temp:" << dPICpuTemp
		  << std::endl;
	gpioHardwarePWM(iPWMgpio, iPWMfreq, iStartStep);
	// gpioSetPWMfrequency	Configure PWM frequency for a GPIO
	// gpioSetPWMrange	Configure PWM range for a GPIO
	printf("Current state:\n");
	printf("\tgpio:%i", iPWMgpio);
	printf("\tdutycycle:%i", gpioGetPWMdutycycle(iPWMgpio));
	printf("\tfrequency:%i", gpioGetPWMfrequency(iPWMgpio));
	printf("\trange:%i", gpioGetPWMrange(iPWMgpio));
	printf("\trealrange:%i\n", gpioGetPWMrealRange(iPWMgpio));
	sleep(3);

	while (dPICpuTemp > 0.0) {
		if ((dPICpuTemp - dLowTemp) < 0.0) {
			iCurFanStep = 0;
		} else if ((dPICpuTemp - dMaxTemp) > 0.0) {
			iCurFanStep = iStartStep;
		} else {
			// 100 : 30
			double dProc = (dMaxTemp - dLowTemp) / 70.0;
			iCurFanStep = 30 + (dPICpuTemp - dLowTemp) / dProc;
		}
		std::cout << ":" << iCurFanStep << ":" << dPICpuTemp << std::endl;
		iCurFanStep = iCurFanStep * iStartStep / 100;
		gpioHardwarePWM(iPWMgpio, iPWMfreq, iCurFanStep);
		sleep(3);
		dPICpuTemp = getPICpuTemp();
	}
	getchar();

	gpioHardwarePWM(iPWMgpio, 0, 0);
	gpioTerminate();

	return 0;
}

