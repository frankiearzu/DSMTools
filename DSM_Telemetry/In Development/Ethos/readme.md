# DSM Telemetry Script Tools for Ethos


# Deployment/Installation

Copy the Uncompressed files into your radio /SCRIPTS/TOOLS

The SDCard should look like this:

    /scripts/dsm-telemetry/main.lua



Tested with X10S Ethos 1.6.0 nightly

---
## Screenshots
![tools-screen](https://github.com/user-attachments/assets/325153a0-8fe7-4ad5-9b71-e5a7bf4a7955)
![SmartTel-main](https://github.com/user-attachments/assets/8893dbea-6f9c-4853-a01e-b8ea648b732f)
![smartTel-FlightLog](https://github.com/user-attachments/assets/c9d30aaa-3f14-4d09-accd-45ee3184886b)
![SmartTel-Safe](https://github.com/user-attachments/assets/eb36abfd-22c0-44e8-a38d-0e24db457f66)
![SmartTel-TextGen-Avian](https://github.com/user-attachments/assets/28ca767a-d62d-4470-9a08-a473b7bb5de3)
![SmartTel-TextGen-Lemon](https://github.com/user-attachments/assets/cf401dc2-9cbc-4984-9deb-d195fe57413e)
![SmartTel-ESC](https://github.com/user-attachments/assets/836c0b0a-58fc-4689-a9f6-3b4ce196f471)

## Versions

## v1.3  
First port to Ethos

## DSM Telemetry

This script has many helpfull telemetry functions for the new "Smart" receivers. AR630,AR631,AR637, etc.
(Requires Ethos 1.6.x or later)

* Flight Log
* TextGen 
    -  Avian ESC programming 
    -  LemonRX Gen2 TEXT Programming
* AS3X Settings:  Flight Mode + Settings 
* SAFE Settings
* ESC Status: Smart ESC Status
* Battery Status: Smart Battery Status
* Flight Pack Amps Consumption


## Video Tutorials
I tried to do the screens as close as posible to the real Spektrum ones.  
Some explanation of the features:

* Flight log:  https://www.youtube.com/watch?v=nZlHA2FEY20
* TextGen: 
    - Avian ESC programing (basic reverse): https://www.youtube.com/watch?v=_ZHWzBWe1e0
    - Avian ESC programming (troubleshootings...) https://www.youtube.com/watch?v=5SdE2Ok2TRU

## DSM Capture

This tool is to capture RAW telemetry data. Usefull when developpers don't have the actual sensors to test, but we can see the RAW data comming in the telemetry messages and write them to the logs.

