# Telemetry screen for OpenTX using FrSky S.Port passthrough protocol

## The script

First attempt to use FrSky passthrough protocol to show telemetry data on a Taranis X9D+. It requires OpenTX 2.2.

Testers are wellcome! Do not hesitate to contact me in case of any doubt.

Most of the data on the display is self explanatory, as you will see in the screenshot taken from OpenTX Companion simulator. The picture is just to show some data, it is not real.

![alt text](https://github.com/jplopezll/OpenTX_FrSkySPort_passthrough_0.0.1-dev/blob/master/images/layoutv001.png "Telemetry screen layout.")

Sections currently implemented and working:
A. Flight Mode, UAV battery voltage, TX battery voltage, timer1 info (mine counts from first thrust).
B. Ground speed in Km/h.
C. GPS altitude.
D. Messages received and severity.
E. Some gauges: RSSI, UAV battery status and current, TX battery remaining (I am using the 6xNiMH battery pack).
F. GPS status and number of satellites.
G. Angle from home launch (this is still to be checked).
H. Distance from home launch (horizontal and vertical).
I. Status flags: armed, battery FS, landed, EKF FS. Also info on UAV battery voltage and capacity to FS trigger.
J. For debugging meanwhile developing: three values on how many 10ms tics the radio is using to get passthrough queue data, drawing and total script execution.

## My setup

I am using a Pixhawk clone v2.4.8 with uBlock GPS module attached linked to a FrSky R-XSR using serial4 with protocol 10 (FrSky passthrough) activated via Mission Planner.

To connect the serial 4 to the R-XSR you need a TTL-Serial inverter adaptor. I have ordered one based on MAX2332, but I am doing the testing with a breadboard, two optocouplers, some resistors and a diode.

You have a nice picture on the required adaptor on this thread <https://github.com/athertop/MavLink_FrSkySPort/issues/11>. Please note the diode that you need to place from TX comming from serial 4 to the S.Port on the R-XSR to block current from the S.Port to the TX pin.