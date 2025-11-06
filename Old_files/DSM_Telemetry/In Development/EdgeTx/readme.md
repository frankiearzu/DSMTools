# DSM Telemetry Script Tools


# Deployment/Installation

Copy the Uncompressed files into your radio /SCRIPTS/TOOLS

The SDCard should look like this:

    /SCRIPTS/TOOLS/
                    DSM_AR636_Tel.lua
                    DSM_SmartRX_Tel.lua
                    DSM_Capture.lua



Tested with Radimaster TX16S and Boxer

---

## Versions

## v1.3
Make the scrip similar for both Ethos and EdgeTX to keep them in Sync

## v1.2  
Fix on Textgen to support smaller screens (like the zorro).. it was not showing the last lines. Move the header to the right side to make more vertical space.

## v1.1  (EdgeTX v2.8.3 or later... no OpenTx)

It uses direct access to the telemetry data (EdgeTX only).  This allow to fix fomating or math problems with the values of the sensors in the tool, instead of the EdgeTX firmware. It bypasses the EdgeTX sensors.

A little better presentation, and more screens supported with similar layout as Spektrum Radios.
Also shows the version of the tools


## v1.0  (use this for OpenTx / EdgeTX version prior to v2.8.3)

Initial version.. uses the EdgeTX Telemetry sensors to get the data.. so you have to do "Discover New" in the EdgeTX telemetry screen. Also if you are adjusting the values via "ratio", use this version.

## DSM_AR636_Tel.lua

This script has many helpfull telemetry functions for Blade Helicopters using AR636 Receiver.  The plane version of AR636 did not expose much info (except current AS3X Gyro Gains)

Tools include:

* Blade Version:  Firmware and product version
* Blade Servo Adjust/Gyro Adjust 
* Blade Alpha6 Monitor
* Plane AS3X-Legacy Monitor
* TextGen  (Requires new EdgeTX 2.8.3 or later)  
   - if you use the same stick and panic button combinations to enter Blade Servo or Gyro adjustment, some Blade receivers have a good TextGen menu to confiture them
* Flight Log"

## DSM_SmartRX_Tel.lua

This script has many helpfull telemetry functions for the new "Smart" receivers. AR630,AR631,AR637, etc.

* Flight Log
* TextGen (Requires new EdgeTX 2.8.3 or later)
    -  Avian ESC programming
    -  LemonRX Gen2 TEXT programming
* AS3X Settings:  Flight Mode + Settings 
* SAFE Settings
* ESC Status: Smart ESC Status
* Battery Status: Smart Battery Status
* Flight Pack Amps Consumption (v1.1)


## Video Tutorials
I tried to do the screens as close as posible to the real Spektrum ones.  
Some explanation of the features:

* Flight log:  https://www.youtube.com/watch?v=nZlHA2FEY20
* TextGen: 
    - Avian ESC programing (basic reverse): https://www.youtube.com/watch?v=_ZHWzBWe1e0
    - Avian ESC programming (troubleshootings...) https://www.youtube.com/watch?v=5SdE2Ok2TRU

## DSM_Capture_Tel.lua

This tool is to capture RAW telemetry data. Usefull when developpers don't have the actual sensors to test, but we can see the RAW data comming in the telemetry messages.

