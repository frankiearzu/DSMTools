
# DSM Tools Suite for EDGETX
All the tools combined in a single app.  Plane-Setup, Forward Prog and Telemetry. 

Is Backward compatible to the files created by the previous version in /MODELS/DSMDATA of Forward Programing, and can Co-Exist with them, even when this provides
the combined functionality.   

**UPDATIND OLDER DSMTools**

If you want to delete the older versions of the multiple individual tools, remove the /SCRIPTS/TOOLS/DSMLIB folder, and "DSM_*" on the main /SCRIPTS/TOOLS folder.. only keep "DSM_Tools.lua" that is the new version.   Your model info is still stored in /MODELS/DSMDATA and is backward compatible.


# DSM Tools Suite (EdgeTX Version)

**NOTE: two versions: BW is for smaller Black & white screen, and color is for color radios**
**The B&W version needs more memory than the stand alone scripts, intended for newer radios like the Boxter, GX12, Zorro, TX12 V2.**
**If it give a memory/error the first time you try to run a sub-menu application, try a second time**
**For older B&W radios, they don't have enouth memory for the suite. Keep using the stand alone scripts**

**UPDATE v2.0-final: Fix SmartBat Telemetry   (Apr 9, 2025)**

**UPDATE v2.0-RC1: Supports AS3X+ Version 3.2.7 firmware   (Jan 7, 2025)**

AS3X and AS3X+ Receiver firmware are supported.

## Installation


* Manual: Unzip and copy the content to your SDCard

After the instalation, the directory folder should look like this:
Color Radios:
<code>
  /MODELS/DSMDATA                -- Where the info about your plane is stored
  /SCRIPTS/TOOLS/DSM_Tools.lua   -- Main program for the TOOLS page
  /SCRIPTS/TOOLS/dsm-tools/
                  apps        -- LUA Applications 
                  i18n        -- Messages displayed on the screen... english only right now.
                  main.lua    -- Main screen for the suit
</code>

The BW radios: will have "_min" at the end of some files:
<code>
  /MODELS/DSMDATA                -- Where the info about your plane is stored
  /SCRIPTS/TOOLS/DSM_Tools_min.lua   -- Main program for the TOOLS page
  /SCRIPTS/TOOLS/dsm-tools-min/
                  apps        -- LUA Applications 
                  i18n        -- Messages displayed on the screen... english only right now.
                  main.lua    -- Main screen for the suit
</code>


## Setup your Plane in EdgeTX first

This needs to be done before plane setup or Forward Programming
1. **RF Internal/External (MultiModule)**:
    - Bind your plane using Spektrum Auto or DSMX-2F, and select a model ID number that you have not used.
    - Make sure that **Enable Max Throws** is **OFF** (Default), Otherwise it will messed up some servo range reported by Forward Prog.
    - **Disable Channel Map** should be **OFF** (Default) is your channel order is AETR (Default). **ON** only if you are using TAER channel order.
    - Make sure that the Channel range is from Ch1-Ch12. For the Flight Mode/Gain channels, you can use channels up to 12 even if your receiver is only 6 channels.
2. **Please setup your plane completely in EdgeTx first!!** This should control the plane.
3. **Channel names:** Give names to a to all the channels.. that will make it easier to identify channels in Forward Prog 
4. **Flight mode switch:** A 3-pos switch for **Flight mode** change
5. **Adjustable Gains:** (Optional) a dial that will be used for adjustable gains.

If your plane is configure in channel Order AETR and **Disable Channel Map=OFF**, the MultiModule and Forward Programming will do the mapping between AETR to TAER that is the Spektrum Standard of how to connect the servos on the RX. On Forward Programming it will show what Port/Ch on the RX, as well as the TX channel assigned.. so you will see something lile <code>Ch1 (TX:Ch3/Throttle)</code> because EdgeTx <code>Ch3/Throttle</code> is mapped to <code>Port1/Ch1</code> on the RX.

Thr channel on the Smart RX is special, and should be the 1st Port/Channel connection. This is to allow ESC telemetry from AVIAN ESCs.


## Main Suite Page

This is the starting point. You can use the rotary encoder or touch to navigate the menus.. <code>RTN</code> key can also be used to get back to the previous screen.

Apps:

1. **Plane Setup:** Capture Spektrum Specific data to Operate the Gyro.. How is your wing configured, what channel operated what surface, and if the surface gyro reaction needs to be reversed.
2. **Forward Programming:** Configuration of the RX.
3. **Telemetry:** Some screens showing telemetry data in a similar way a Spektrum radio shows them.
4. **Capture:** This is a tool to capture the raw telemetry data, and write it to a log file. That data is very usefull to add new/unsoported Spektrum sensors to DSMTools. 

![image](https://github.com/user-attachments/assets/27d8cb21-c784-4139-9e8f-cb4f085beee3)

![image](https://github.com/user-attachments/assets/4596809b-97d9-48e4-aa6b-ceb2e7769715)


## Plane Setup
In this app, we need to capture some extra model information that is needed for the AS3X gyro to
work properly.  

Currently, only supports Airplanes, but if you are going to use Forward Prog for Blade helicopter, 
just configure a basic 4-channel plane.  

What information is needed by AS3X:
* **What Wing and Tail type:** Only the basic surfaces operated by the Gyro are needed (Thr,Ail,Elv,Rud).. Flaps are ignored. This also provides information of the type of mix that will be applied on special cases: V-Tail, Deltas, Tailerons
* **What channel moves each surface**
* **Gyro Reaction: Normal/Reverse:** If reaction is not right, here is where you reverse it!
* **Servo Setting information:**   This comes from EdgeTX Output page, is shared with the RX, but no need to manually set it up.
  * Servo Travel range (%)
  * Sub-Trims

![image](https://github.com/user-attachments/assets/81f1171e-8d51-46f5-9941-bee0c98611a8)

![image](https://github.com/user-attachments/assets/989e21b9-60f1-4242-b381-ccb612b916b5)


## Forward Prog
Forward Programming is a way to configure the Spektrum RX from your transmitter. Think of it as how a Web-Browser works; The menu actually comes from the RX. The TX only renders the menu on the TX display. The menus should look very close to how a Spektrum TX will show it.  We are not intending to tech you how to do the Gyro AS3X/SAFE configuration here.. for that any Spektrum Forward Programming video will give you the idea.

When you are editting a field that is to select a channel, you can also just move the switch/dial to select it.. thats why you want to get your switches done before.

![image](https://github.com/user-attachments/assets/40a1d411-c5f2-473b-80f6-3d075bfa1623)

![image](https://github.com/user-attachments/assets/5d66e565-0ac3-4461-920a-7964e49ef8fb)




## Telemetry 

This is a set of screens showing telemetry information in a similar way that a Spektrum TX would do.
Some basic ones:

* **Flight Log:** this screen shows how good your link quality is.. **F** for Frame losses, and "H" for Holds (total disconnect from TX).
* **TextGen:**  This is a tool that is used to configure Spektrum AVIAN ESCs as well as new Gen 2.1 LemonRX "TexGen" receivers.


![image](https://github.com/user-attachments/assets/0f404215-1d43-4872-9f40-f2969ac5f29a)

![image](https://github.com/user-attachments/assets/b05efbf3-43f6-4305-a3af-85545b8ba40c)

![image](https://github.com/user-attachments/assets/0cea8799-06c6-4993-8ed1-dcd2527a5e39)

![image](https://github.com/user-attachments/assets/3d9acae1-0f25-4e8e-a630-5cc44867adc8)


## Video/Tutorials

You can visit my channel for some basic videos:  https://www.youtube.com/@franciscoarzu8120

Shane's DIY has some good Forward Programming tutorials using EdgeTX, but should be the same in Ethos once you star forward Programming:
https://www.youtube.com/@shanesdiy/videos

Any Spektrum Forward Programming video teaching how to do Forward Programming is applicable.  https://www.youtube.com/@SpektrumRCvideos







