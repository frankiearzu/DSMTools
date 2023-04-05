# Credits
Code is based on the code/work by: Pascal Langer (Author of the Multi-Module) 
Rewrite/Enhancements by: Francisco Arzu

Thanks to all the people volunteered to test it.

# Introduction  (v0.54  Beta) LIMITED FUNCTIONALITY

Many of the 128x64 small screen radios has very limited memory.  Currently this version only supports changing existing setting, but
will not work to setup a plane from zero or a new receiver.

Will continue working on creating a separate program to setup the plane, but will take some time.
Splitting the functionaluty into multiple tools is the only way to deal with the limited memory.

IF YOU SEE MENU OPTIONS WHO STARTS WITH `DONT USE:` please don't select that option since is not going to work.


# Deployment

Uncompress the Zip file (ZIP version) into your local computer.
In another window, open your TX SDCard and go to `/SCRIPTS/TOOLS`.

When upgrading from a previous version of this tool, delete your `/SCRIPTS/TOOLS/DSMLIB` before copying the new one (if you customized the menu messages, inside `DSMLIB` do a backup of the message files first)

1. Copy the entire `DSMLIB` folder into `/SCRIPTS/TOOLS`, now your will have `/SCRIPTS/TOOLS/DSMLIB` in your SDCard .

2. Copy the main script you want to use (MIN).

Your TX SDCard should looks like this:

    /SCRIPTS/TOOLS
        DsmFwdPrg_05_MIN.lua     -- black/white 128x64 Minimal version 

    /SCRIPTS/TOOLS/DSMLIB/       -- (ALL CAPITALS) Libraries ane extra files
        msg_en.txt               -- Menu messages in English  (common for all radios)
        msg_MIN_en.txt           -- Menu messages in English  (custumized messages for 128x164 resolution)

### Other Directories/Files

    /LOGS/dsm_log.txt		       	--Readable log of the last RX/TX session, usefull for debugging problems



# Common Questions
1. `RX not accepting channels higher than Ch6 for Flight-mode o Gains:`
    - All Spektrum RX are 20 channels internally, even if it only has 6 external Ch/Ports to connect servos.

    - Make sure that when you bind your RX, you select the proper range of channels to use.. By default, ch1-ch8.
    
    - You have to mapped a Switch/Slider to the channel, togling/moving  will select the channel on the menu field.

    - The RX validates the channels, and it does not detect signal on a channel, it will not allow to select it..that is why is important to move the switch/slider, so that the RX knows that is a valid channel.   


# Changes and fixes 
V0.54 Beta:
- First version for the small screens, and limited memory.  Only can change existing values, it cannot setup a brand new plane or new RX from Zero
- Fix problem on editing the SAFE Mode Attitude Trim
- First version with externalize merges, so that it can be translated to other languages

# Tested Radios and RXs
- Radio: FrSky QX7 
- AR631/AR637xx
- FC6250HX (Blade 230S V2 Helicopter)
- AR636 (Blade 230S V1 Heli firmware 4.40)

Please report if you have tested it with other receivers to allow us to update the documentation. Code should work up to 10 channels for the main surfaces (Ail/Ele/etc).  All Spektrum RX are internally 20 channels, so you can use Ch7 for Flight Mode even if your RX is only 6 channels (See common Questions)

# Messages Displayed in the GUI

If in a screen you get text that looks like `Unknown_XX` (ex: Unknown_D3), that message has not been setup in the script in english. If you can determine what the proper message is,  you can send us a message to be added to the library.
The `XX` represents a Hex Number (0..9,A..F)  message ID. 

If you want to fix it in your local copy, all messages are in the file `SCRIPT\TOOS\DSMLIB\msg_en.txt`. (english version)

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

If you want to translate the menu messages to another language (like french), copy the file `msg_en.txt` into `msg_fr.txt`, translate it, and change the language in the lua file to `"fr"`.


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
 
