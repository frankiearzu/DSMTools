# DSM Telemetry Script Tools


# Deployment/Installation

Copy the Uncompressed files into your radio /SCRIPTS/TOOLS

The SDCard should look like this:

    /SCRIPTS/TOOLS/
                    DSM_AR636_Tel.lua
                    DSM_SmartRX_Tel.lua



Tested with Radimaster TX16S and FrSky QX7

# ScreenShots
![tools-screen](https://github.com/user-attachments/assets/325153a0-8fe7-4ad5-9b71-e5a7bf4a7955)
![SmartTel-main](https://github.com/user-attachments/assets/8893dbea-6f9c-4853-a01e-b8ea648b732f)
![smartTel-FlightLog](https://github.com/user-attachments/assets/c9d30aaa-3f14-4d09-accd-45ee3184886b)
![SmartTel-Safe](https://github.com/user-attachments/assets/eb36abfd-22c0-44e8-a38d-0e24db457f66)
![SmartTel-TextGen-Avian](https://github.com/user-attachments/assets/28ca767a-d62d-4470-9a08-a473b7bb5de3)
![SmartTel-TextGen-Lemon](https://github.com/user-attachments/assets/cf401dc2-9cbc-4984-9deb-d195fe57413e)
![SmartTel-ESC](https://github.com/user-attachments/assets/836c0b0a-58fc-4689-a9f6-3b4ce196f471)



---

## Versions

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

* AS3X Settings:  Flight Mode + Settings 
* SAFE Settings
* ESC Status: Smart ESC Status
* Battery Status: Smart Battery Status
* TextGen (Requires new EdgeTX 2.8.3 or later)
    -  Avian ESC programming
* Flight Pack Amps Consumption (v1.1)
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

