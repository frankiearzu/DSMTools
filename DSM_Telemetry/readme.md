# DSM Telemetry Script Tools


# Deployment/Installation

Copy the Uncompressed files into your radio /SCRIPTS/TOOLS

The SDCard should look like this:

    /SCRIPTS/TOOLS/
                    DSM_AR636_Tel.lua
                    DSM_SmartRX_Tel.lua



Tested with Radimaster TX16S and FrSky QX7


## DSM_AR636_Tel.lua

This script has many helpfull telemetry functions for Blade Helicopters using AR636 Receiver.  The plane version of AR636 did not expose much info (except current AS3X Gyro Gains)

Tools include:

* Blade Version:  Firmware and product version
* Blade Servo Adjust
* Blade Gyro Adjust 
* Blade Alpha6 Monitor
* Plane AS3X Monitor
* TextGen  (Requires new EdgeTX 2.8.3 or later)  
   - if you use the same stick and panic button combinations to enter Blade Servo or Gyro adjustment, some Blade receivers have a good TextGen menu to confiture them
* Flight Log"

## DSM_SmartRX_Tel.lua

This script has many helpfull telemetry functions for the new "Smart" receivers. AR630,AR631,AR637, etc.

* AS3X Settings:  Flight Mode + Settings 
* SAFE Settings
* ESC Status: Smart ESC Status
* Battery Status: Smart Battery Status
* TextGen (Requires new EdgeTX 2.8.3 or later)
    -  Avian ESC programming
* Flight Log

## Video Tutorials
I tried to do the screens as close as posible to the real Spektrum ones.  
Some explanation of the features:

* Flight log:  https://www.youtube.com/watch?v=nZlHA2FEY20
* TextGen: 
    - Avian ESC programing (basic reverse): https://www.youtube.com/watch?v=_ZHWzBWe1e0
    - Avian ESC programming (troubleshootings...) https://www.youtube.com/watch?v=5SdE2Ok2TRU

## DSM_Capture_Tel.lua

This tool is to capture RAW telemetry data. Usefull when developpers don't have the actual sensors to test, but we can see the RAW data comming in the telemetry messages.

