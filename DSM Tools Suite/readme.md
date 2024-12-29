
# DSM Tools Suite
All the tools combined in a single app.


# DSM Tools Suite (Ethos Version)

**NOTE:  Requires Ethos 1.6.0 or newer**
A release candidate one (v 2.0 RC3) is posted here, should work on Simulators (with mocked RX data), as well as the real radios.
Tested it on X10, X18rs and X20s.  

Starting with version 2.0 to get in synch with the new EdgeTX versions.

AS3X and AS3X+ Receiver firmware are supported.

## Installation

There are two ways to install the tools:
* Ethos Suite:  Just select the zip file, and select **dsm-tools** to install.
* Manual: Unzip and copy the directory/folder **dsm-tools** to you **/scripts** directory

After the instalation, the directory folder should look like this:
<code>
  /scripts/dsm-tools/
                  apps        -- LUA Applications 
                  data        -- This is where the Spektrum specific model data is stored. if upgrading, don't delete it!!
                  logs        -- Logs for telemetry Capture, and the last Forward Programming conversation with the RX
                  i18n        -- Messages displayed on the screen... english only right now.
                  main.lua    -- Main screen for the suit
</code>

## Setup your Plane in Ethos

This needs to be done before plane setup or Forward Programming
1. **RF system/External (MultiModule)**:
    - Bind your plane using Spektrum DSMX-2F, and select a model ID number that you have not used.
    - Make sure that **Enable Max Throws** is **OFF** (Default), Otherwise it will messed up some servo range reported by Forward Prog.
    - **Disable Channel Map** should be **OFF** (Default) is your channel order is AETR (Default). **ON** only if you are using TAER channel order.
    - Make sure that the Channel range is from Ch1-Ch12. For the Flight Mode/Gain channels, you can use channels up to 12 even if your receiver is only 6 channels. 
2. **Please setup your plane completely in Ethos first!!** This should control the plane.
3. **Channel names:** Give names to a to all the channels.. that will make it easier to identify channels in Forward Prog 
4. **Flight mode switch:** A 3-pos switch for **Flight mode** change
5. **Adjustable Gains:** (Optional) a dial that will be used for adjustable gains.



If your plane is configure in channel Order AETR and **Disable Channel Map=OFF**, the MultiModule and Forward Programming will do the mapping between AETR to TAER that is the Spektrum Standard of how to connect the servos on the RX. On Forward Programming it will show what Port/Ch on the RX, as well as the TX channel assigned.. so you will see something lile <code>Ch1 (TX:Ch3/Throttle)</code> because Ethos <code>Ch3/Throttle</code> is mapped to <code>Port1/Ch1</code> on the RX.

Thr channel on the Smart RX is special, and should be the 1st Port/Channel connection. This is to allow ESC telemetry from AVIAN ESCs.


## Main Suite Page

This is the starting point. You can use the rotary encoder or touch to navigate the menus.. <code>RTN</code> key can also be used to get back to the previous screen.

Apps:

1. **Plane Setup:** Capture Spektrum Specific data to Operate the Gyro.. How is your wing configured, what channel operated what surface, and if the surface gyro reaction needs to be reversed.
2. **Forward Programming:** Configuration of the RX.
3. **Telemetry:** Some screens showing telemetry data in a similar way a Spektrum radio shows them.
4. **Capture:** This is a tool to capture the raw telemetry data, and write it to a log file. That data is very usefull to add new/unsoported Spektrum sensors to Ethos. 

![image](https://github.com/user-attachments/assets/22a280e3-3f4b-4591-ac82-e8a2c4ec3193)
![image](https://github.com/user-attachments/assets/0da5693b-025c-40a1-b465-81f8fd258fcd)

## Plane Setup
In this app, we need to capture some extra model information that is needed for the AS3X gyro to
work properly.  

Currently, only supports Airplanes, but if you are going to use Forward Prog for Blade helicopter, 
just configure a basic 4-channel plane.  

What information is needed by AS3X:
* **What Wing and Tail type:** Only the basic surfaces operated by the Gyro are needed (Thr,Ail,Elv,Rud).. Flaps are ignored. This also provides information of the type of mix that will be applied on special cases: V-Tail, Deltas, Tailerons
* **What channel moves each surface**
* **Gyro Reaction: Normal/Reverse:** If reaction is not right, here is where you reverse it!
* **Servo Setting information:**   This comes from Ethos Output page, is shared with the RX, but no need to manually set it up.
  * Servo Travel range (%)
  * Sub-Trims

![image](https://github.com/user-attachments/assets/a642302a-98fe-4755-a0ac-5ac63232ba95)
![image](https://github.com/user-attachments/assets/f6fb3f22-6e82-40eb-aae0-5004d5a67ec9)

## Forward Prog
Forward Programming is a way to configure the Spektrum RX from your transmitter. Think of it as how a Web-Browser works; The menu actually comes from the RX. The TX only renders the menu on the TX display. The menus should look very close to how a Spektrum TX will show it.  We are not intending to tech you how to do the Gyro AS3X/SAFE configuration here.. for that any Spektrum Forward Programming video will give you the idea.

When you are editting a field that is to select a channel, you can also just move the switch/dial to select it.. thats why you want to get your switches done before.

![image](https://github.com/user-attachments/assets/686fae9b-68a3-4273-81d6-569f18252e20)
![image](https://github.com/user-attachments/assets/b7290f69-fc74-4483-8980-003f83666fe3)


## Telemetry 

This is a set of screens showing telemetry information in a similar way that a Spektrum TX would do.
Some basic ones:

* **Flight Log:** this screen shows how good your link quality is.. **F** for Frame losses, and "H" for Holds (total disconnect from TX).
* **TextGen:**  This is a tool that is used to configure Spektrum AVIAN ESCs as well as new Gen2 LemonRX receivers.


![image](https://github.com/user-attachments/assets/e723c10f-1093-4fed-ac40-d1ca23381248)
![image](https://github.com/user-attachments/assets/1de92ca8-ea0d-41ea-aeb1-4690022170f4)
![image](https://github.com/user-attachments/assets/ab2bcc3b-1fbd-4629-8d96-2c5fe11d024b)
![image](https://github.com/user-attachments/assets/c8d9d45e-86d3-486c-acf0-bbe7e1b149c7)


## Video/Tutorials

You can visit my channel for some basic videos:  https://www.youtube.com/@franciscoarzu8120

Shane's DIY has some good Forward Programming tutorials using EdgeTX, but should be the same in Ethos once you star forward Programming:
https://www.youtube.com/@shanesdiy/videos

Any Spektrum Forward Programming video teaching how to do Forward Programming is applicable.  https://www.youtube.com/@SpektrumRCvideos







