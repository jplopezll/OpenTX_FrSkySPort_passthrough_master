# Telemetry screen for OpenTX using FrSky S.Port passthrough protocol

## The script

FrSky passthrough protocol to show telemetry data on a Taranis X9D+. It requires OpenTX 2.2. Use the script "spptel.lua".

This version is fully functional, some functionalities (orientation and distances from home) to be verified on the field. Testers are wellcome! Do not hesitate to contact me in case of any doubt.

Most of the data on the display is self explanatory, as you will see in the screenshot taken from OpenTX Companion simulator. The picture is just to show some data, it is not real.

![alt text](https://github.com/jplopezll/OpenTX_FrSkySPort_passthrough_0.0.1-dev/blob/master/images/layoutv002.png "Telemetry screen layout.")

Sections currently implemented and working:

A. Flight Mode, UAV battery voltage, TX battery voltage, timer1 info (mine counts from first thrust).

B. Ground speed in Km/h.

C. GPS altitude.

D. Messages received and severity. Up to 10 messages are recorded in a FIFO buffer. Number indicates order from 0, last message, to 10, oldest message. Scroll is possible with the (+) and (-) keys.

E. Some gauges: RSSI, UAV battery status and current, TX battery remaining (I am using the 6xNiMH battery pack).

F. GPS status and number of satellites.

G. Angle from home launch (this is still to be checked on the field).

H. Distance from home launch (horizontal and vertical, also to be checked on the field).

I. Status flags: armed, battery FS, landed, EKF FS. Also info on UAV battery voltage and capacity to FS trigger.


## My setup

I am using a Pixhawk clone v2.4.8 with uBlock GPS module attached linked to a FrSky R-XSR using serial4 with protocol 10 (FrSky passthrough) activated via Mission Planner.

To connect the serial 4 to the R-XSR you need a TTL-Serial inverter adaptor. I am using a protoboard with a MAX232N, four 1uF capacitors and a diode. I have also done some testing with a circuit based on optocouplers, some resistors and a diode (this also worked well).

I will be running the quad with a specific adaptor. You have a nice picture on the required adaptor on this thread <https://github.com/athertop/MavLink_FrSkySPort/issues/11>. Please note the diode that you need to place from TX comming from serial 4 to the S.Port on the R-XSR to block current from the S.Port to the TX pin.

In case anybody would be interested, I was able to program one arduino nano to work as a TTL-Serial inverter-converter. You only need the arduino and a diode. I added a resistor to avoid problems overloading input and output pins. Open an issue if anybody wants the code.

## Sniffer available

If you want to know what is your radio getting from the passthrough, you can use the script called "spsnif.lua".

It will store data received in /SCRIPTS/TELEMETRY/sportlog.txt in csv format for later on analysis.

I would recommend to disable all other telemetry screens and configure spsnif as the only script to be run. It displays only a few numbers and should be able to capture most (if not all) of the data entering the radio.

## Sniffer available

And if you want to check the telemetry rates, you can use the scritp "sprate.lua". It will show you the number of packets of each 0x500x received every 10 seconds.

I used this to verify how much info was being handled by the sript as with some versions of the code I was having delays of up to 4 seconds from movement on the flight controller to reaction on the lcd screen of the Taranis.