# DSM Telemetry Script Tools for Ethos


# Deployment/Installation

Copy the Uncompressed files into your radio /SCRIPTS/TOOLS

The SDCard should look like this:

    /scripts/dsm-telemetry/main.lua



Tested with X10S Ethos 1.6.0 nightly

---

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

