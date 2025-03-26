# Credits
Code is based on the code/work by: Pascal Langer (Author of the Multi-Module) 
Rewrite/Enhancements by: Francisco Arzu

Thanks to all the people volunteered to test it.
# Note

EdgeTX 2.11 seems to not like the long filenames.. so if you are using 2.11, rename the files and change the part "FwrdPrg" to "FP" in the filename to make them sorter.   I think this will be fixed on EdgeTX, but this is the temporary workaround.

Due to memory, it will not run on all radios. So far this is what we know.

1. FrSky Taranis X9D:  Not enouth memory
2. FrSky Taranis X9D+ 2019: works
3. FrSky Taranis QX7:  Works sometimes.. see note related to memory usage below
4. Radimaster  TX12:  No reports yet
5. Radimaster TX12 MK2: yes
6. Radiomaster Zorro: Yes
7. Radiomaster Boxter: Yes
8. Radiomaster Pocket w 4-in-1: yes


# Introduction  (v0.59a Black & White  Small Radios)

UPDATE: v0.59a support new Spektrum RX firmware version AS3X+ v3.2.7

# How to Use it

Step #1: Make sure that the /MODELS/DSMDATA folder exist.

Step #2: Run the "DSM FwdPrg_59_STUP" first to setup the plane wing, tail and channels to use for each surface. At the end it will ask you to "save" the configuration. That saves a file in the /MODELS/DSMDATA folder.

![image](https://github.com/frankiearzu/DSMTools/assets/32604366/be03ad40-3e2f-45e1-8f50-d231c3931169)
![image](https://github.com/frankiearzu/DSMTools/assets/32604366/5010a361-1234-4c83-97b2-2eb6ae0d1061)
![image](https://github.com/frankiearzu/DSMTools/assets/32604366/0d4e04dc-90d7-4322-9ad1-f57cbde49029)

Why the RX needs to know the Plane Setup??   The AS3X/Gyro and SAFE needs to know what surfaces to move to do the proper correction in flight. It needs to know what channels are you using for ailerons, elevarors and rudders (could be 1 or 2 of each). Also if you have special Wing like a delta wing, the elevator and aileron functions are on the same channels.. same with V-Trails, Ruder/Elevator are combined. All this information is shared with the RX during "First Time Setup" as well as "Relearn Servo Setting".   Older version of 0.55 MIN hardcoded this info to be a plain 4-ch regular plane, thats why we discourage to use those function.


Step #3: Run the "DSM FwdPrg_58_MIN". It uses the model configuration created in step #2 to properly tell the receiver the plane configuration for initial setup.  If you get "Cannot load model config", that means that the file was not created on step #2.   Once it shows the intial forward programming page for your receiver, usuall "Gyro Settings and Other Settings". You can properly setup the a plane from initial setup... if you are not familiar with this step, view some of the videos. There are already multiple videos showing how to do it EdgeTX color version, or the Spektrum official videos, the menus are the same.


## Dealing with Low memory
On my FrSky QX7 (Probably the one with the lower memory compared to Radiomaster Boxter and maybe Zorro), it will give you "not enouth memory"
the very first time you try to run it since is compiling + running. Try to run them at least 2 times again, this times wll just run (not compile).
In some ocations that keeps giving memory problems, i have to restart the radio, and try to run it right after restart.

After it runs fine, and you try to run it the 2nd time and gives "not enouth memory", you have restart the radio.. for me this is random.. 
sometimes i can run it many times consecutively.. but once it gives memory error, have to restart to be able to run again. 
Once it starts, it should work find after... is the statup who loads what it needs to memory.

I am running EdgeTX 2.9.2 (there was some memory cleanup in 2.9.0, and 2.9.1 to get a bit more memory)
I left version 0.55 in the files, since it uses less memory, it can change the mayority of FP parameters, but cannot setup plane or Relearn Servo Settings
(don't execute the menus who say 'DON'T USE!!').. v0.55 and v0.56 MINs can co-exist.

Video of how to deal with memory:
https://www.youtube.com/watch?v=kG3RfVa_brU

# Deployment

Uncompress the Zip file (ZIP version) into your local computer.
In another window, open your TX SDCard and go to `/SCRIPTS/TOOLS`.

When upgrading from a previous version of this tool, delete your `/SCRIPTS/TOOLS/DSMLIB` before copying the new one (if you customized the menu messages, inside `DSMLIB` do a backup of the message files first)

1. The zip file has the same structure as your SDCard. If you want to copy all the content of the zip file into your SDCard, it will create all the directories and files in the right place.

For the MINimalistic version, Your TX SDCard should looks like this:

    /SCRIPTS/TOOLS
        DSM FwdPrg_59_MIN.lua     -- Minimalistic version for radios with LOW memory (Can setup planes)
        DSM FwdPrg_59_STUP.lua    -- `NEW!` Setup plane for minimalistic version (LOW Memory radios)

    /SCRIPTS/TOOLS/DSMLIB/       -- (ALL CAPITALS) Libraries ane extra files
        DsmFwPrgMIN_P1.lua            -- Part1 of extra files for Min
        DsmFwPrgMIN_P2.lua            -- Part2 of extra files for Min
        msg_fwdp_en.txt               -- Menu messages in English  (common for all radios)
        MIN_msg_fwdp_en.txt           -- Menu messages in English  (overrides for 128x164 resolution)

### Other Directories/Files

    /LOGS/dsm_log.txt		       	--Readable log of the last RX/TX session, usefull for debugging problems

# NOTE for FC6250HX FC+RX version
For the full size FC6250HX, Only use V0.55 or newer.

DO NOT use previous versions to do the Setup -> Gyro Settings -> Orientation. The problem was that it did not have the orientation messages.. and you are were choosing blind. The calibration will never stop until you place the RX in the right orientation, even after restarting the RX (if flashing red, is not in the right orientation.. if flashshing white is in the right orientation).  If you run into this problem, and lights are blinking red, rotate the FC on the longer axis until you get white blinking.. keep it stable, will blink white faster andlet calibration finishes.. after that is back to normal.

OpenTX: When you enter "forward programming" you will hear "Telemetry lost" and "Telemetry recovered".. The FC led will blink white, but when exit FP, will blink red...is not problem.. but will need to be power cycled to get blinking green again.. i think is something related to temporarilly loosing the connection with the radio..researching the OpenTX code since it only happens with this helis FC. 

# Common Questions
1. `RX is not detected:` Forward Prog needs the telemetry return to be working properly to get the menus from the RX. Make sure that you bind the RX with DSM-X2F, or If you use "Auto", after binding, verify that it resolved to X2F. Also do model->telemetry->"discover sensors" and make sure that you are getting the sensors refreshed. Also remember that Forward programming is only supported in newer "smart" line of RXs... The Airplane AR636 don't have FP, But AR630/AR631/AR637 who are common, does.

3. `RX not accepting channels higher than Ch6 for Flight-mode o Gains:`
- V0.55 and newer:  Problem solved.. Should allow you to select up to 12ch with the switch technique or with the scroller.

- V0.53/0.54:  The RX is listening to channel changes for this options. Configure the Switch to the channel, togling once the switch will select the channel on the menu field.  

3. `Only able to switch to Fligh-mode 2 and 3, but not 1:`
Check that the module "Enable max throw" is OFF in you Multi-Module settings (where you do BIND), otherwise the TX signals will be out of range.
The multi-module is already adjusting the TX/FrSky servo range internally to match Spektrum.

4. `Why Ch1 says Ch1 (TX:Ch3/Thr)?`:
 Radios with Multi-Module are usually configured to work the standard AETR convention. Spektrum uses TAER. The multi-module does the conversion when transmitting the signals. So `Spektrum Ch1 (Throttle)` really comes from the `TX Ch3`.  We show both information (+name from the TX output).  If your multi-module/radio is setup as TAER, the script will not do the re-arrangement.  

5. `If i change the model name, the original model settings are lost.` This is correct, the model name is used to generate the file name (inside /MODEL/DSMDATA) who stores the model configuration. Currently EdgeTx and OpenTX has differt features where i could get either the Model Name or the YAML file where the EdgeTX model configuration is stored.. to keep the code compatible, the model name is used.

6. `Reversing a channel in my TX do not reverse the AS3X/SAFE reaction.` Correct, the chanel stick direction and the Gyro direction are two separate things.

    6.1: First, you have setup your model so that the sticks and switches moves the surfaces in the right direction.
 
    6.2: Go to the script, `Model Setup` and setup your wing type, tail type, and select the channel assigment for each surface. Leave the servo settings the same as the values in the TX to start.
 
    6.3: Go to `Forward programming->Gyro Setting->Initial Setup` (New/factory reset), or `Forward programming->Gyro Setting->System Setup->Relearn Servo Settings` (not new). This will load your current Gyro servo settings into the plane's RX. This moves the current servo TX settings to the RX, so it is now in a known state.
 
    6.4: Verify that the AS3X and SAFE reacts in the proper direction. You can use the Flight mode configured as "Safe Mode: Auto-Level" to see if it moves the surfaces in the right direction.  
 
    6.5: If a surface don't move in the right direction, go to the `Model Setup->Gyro Channel Reverse` to reverse the Gyro on the channels needed, and do again the `Forward programming->Gyro Setting->System Setup->Relearn Servo Settings` to tranfer the new settings to the RX.

    6.6: Specktrum TX always passes the TX servo reverse as the Gyro Reverse, but on many OpenTX/EdgeTX radios, the Rud/Ail are usually reversed by default compared to Specktrum. So far i don't think that i can use this as a rule, that is why the `Gyro Channel Reverse` page exist. 
    
---
--- 


# Changes and fixes 
v0.59a:
Support for new Spektrum Firmware AS3X+ v3.2.7 

v0.58:
Support for new Spektrum Firmware 3.x that introduce AS3X+ to many common receivers.

v0.57:
1.  In EdgeTX 2.10.x, sometimes the /LOGS dirctory/folder gets currupted after using some Lua scripts who writes to the logs. To avoid any problems, this version has the writting to the logs turned OFF.  It can be turn on later if needed for debuging purposes. Besides that, is the same as v0.56

v0.56:
1. Fix Tail-Type "Taileron" functionality that was not working. Also validated V-Tail and Delta wings.
2. Added Taileron and two Rudder config (Many Freewing Jets like F18,F16, etc)
3. Gyro-Reverse Screen now shows what is the channel/port used for (Ail, Ele, Rud, etc)
4. COLOR ONLY: Gyro-Reverse Screen now shows what information that shared with the RX about each channel (Role, Slave, Reverse).
5. NEW!! Initial version of Plane Setup for B&W radios

V0.55:
1. Finally found where the TX reports to the RX how many channels is transmiting. The TX now reports itself as a 12ch radio instead of 6h. (DSM Multi-Module limit).  This fixes a few things:
    
    a. Many places where you have to select channels > CH6 for Flight-Mode, Gains, Panic now works properly with the scroller. The radio is still validating that you are not selecting an invalid channel. For example, if you have an additional AIL on CH6, it will not allow you to use CH6 for FM or Gains.. it just move to the next valid one.

    b. When setting up AIL/ELE on channels greater than CH6, on previous versions SAFE/AS3X was not moving them.. now they work up correctly.  Set them up in the first in CH1-CH10.  Why CH10?? Thats what fits on the reverse screen, otherwise, have to add more screens.

    c. Some individual Gain channels was not allowing to setup on CH greater than CH6. Now is fixed.

2. User Interface:
    a. `RTN` Key now works as `Back` when the screen has a `Back`. Makes it easy for navigation.. Presing `RTN` on the main screen exists the tool.
    b. Much faster refresh of the menus. Optimize the process of send/recive menu data from the RX.

3. Support for FC6250HX (the one with separate RX).. Setup Swashplate type, RX orientation works properly.. This are menu options that the smaller version that comes in the
Blade 230S did not have.

V0.54 Beta:
- First version for the small screens, and limited memory.  Only can change existing values, it cannot setup a brand new plane or new RX from Zero
- Fix problem on editing the SAFE Mode Attitude Trim
- First version with externalize merges, so that it can be translated to other languages

# Tested Radios and RXs
- Radio: FrSky QX7:   Due to limited memory, could be that the first time is does not start (not enouth memory to compile+run), but try again after a fresh TX restart.

- AR631/AR637xx
- FC6250HX (Blade 230S V2 Helicopter)
- FC6250HX (Separate RX.. use only V55 or newer of this tool)
- AR636 (Blade 230S V1 Heli firmware 4.40)

Please report if you have tested it with other receivers to allow us to update the documentation. Code should work up to 10 channels for the main surfaces (Ail/Ele/etc).  All Spektrum RX are internally 20 channels, so you can use Ch7 for Flight Mode even if your RX is only 6 channels (See common Questions)

# Messages Displayed in the GUI

If in a screen you get text that looks like `Unknown_XX` (ex: Unknown_D3), that message has not been setup in the script in english. If you can determine what the proper message is,  you can send us a message to be added to the library.
The `XX` represents a Hex Number (0..9,A..F)  message ID. 

If you want to fix it in your local copy, all messages are in the file `SCRIPT\TOOS\DSMLIB\msg_fwdp_en.txt`. (english version)

Example::

    T |0x0080|Orientation
    T |0x0082|Heading
    T |0x0085|Frame Rate
    T |0x0086|System Setup
    T |0x0087|F-Mode Setup
    T |0x0088|Enabled F-Modes
    T |0x0089|Gain Channel
    T |0x008A|Gain Sensitivity/r  -- Right Align
    T |0x008B|Panic
    T |0x008E|Panic Delay

For example, if you get `Unknown_9D` in the GUI and your now that it should say **NEW Text**, you can edit the lua script to look like this:
    T |0x009D|NEW Text -- NEW Text added for AR98xx

# Local Language Support 
Some settings that can change (top of Lua file):
`local LANGUAGE            = "en"`

If you want to translate the menu messages to another language (like french), copy the file `msg_fwdp_en.txt` into `msg_fwdp_fr.txt`, translate it, and change the language in the lua file to `"fr"`.


# LOG File

The log file of the last use of the script is located at `/LOGS/dsm_log.txt`. **It is overridden on every start to avoid filling up the SD card**. So if you want to keep it, copy or rename it before starting the script again. (it can be renamed in the TX by browsing the SD card)

The log is human readable, and can help use debug problems remotrly


# Validation of data by the RX

When you change a value in the GUI, the RX validates that the value is valid.  This applies to channels as well as values.


---
# Version 0.54
First version for Small Radios

### Known Problems:
- Currently cannot setup a plane from scratch.. (Working on it).
- The first time you run it, it will give you "not enouth memory", but should work the 2nd time after the first compilation (creation of .luac). After that, it should start right away.
 
# Version 0.2
Original Version from Pascal Langer
 
