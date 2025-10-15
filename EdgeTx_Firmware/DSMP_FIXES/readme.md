<h1> EdgeTX Fixes For Lemon DSMP </h1> 

This firmware is from the branch 2.11, wich contains the latest is 2.11.3 + some other fixes that will become 2.11.4.. still not official to fly.


What i recomend is to do a backup of your edgetx SDCARD in case you need to go back.
Usually EdgeTX works great going forward, but sometimes, going back can change some configs.
If you have a Spare SDCARD, you can use that just for testing, by copying your content of your SDCARD.

1. Backup SDCARD  (Or swich to a testing SDcard)
2. Copy new firmware to /FIRMWARE folder
3. Start in bootloader modes (Trims In + Power), select new firmware file.
4. To go back, Install old firmware (bootload more).
5. Restore SDCard from backup (or put your "flying" SDCARD.. make sure you have the firmware updated before putting SDCARD update/replace).


<h2>Reported Bug on EdgeTX and RC Groups</h2>

1. Some channels only move 1/2 way  (only to the center-right, but not center-left). 
    -   Happened once to me, but haven't be able to replicate.
2. Frozen channels for a bit.   
    -   Could be the refresh problem below
3. Ch7-Ch12 not refreshed
    -   Maybe the refresh problem, or something else.
4. Weird movements after BIND, has to restart TX to correct it
    -   Was able to replicate. Fixed
5. On some LemonRX receives, not getting telemetry with DSMP, but same RX works with MultiModule.
    -   Replicated with 1 old Gen2, but not with recent ones. 

<h2>EdgeTX changes Oct 15, 2025 (Serial LemonDSMP interface)</h2>

1. Change message/channels send cycle time from 11ms to 22ms..  DSMP is expecting to receive in 22ms cycles
    - This was causing 1 edgetx channel refresh message to be lost on every cycle
    - Probaly not as critical in normal use, since all channels will eventually get refreshed, but at one time, one of my channels froze for about 
      2s, that could be explained by loosing the message consistently for a bit. 1 message for ch1-6, and another 
      for ch7-12, at 2.2s, an extra status message is send, so it changes the order.. now ch7-12 first, then ch1-6;
    - Critical for Forward programming. FP is a command/response protocol. if the command (TX->RX) is lost, no response. 
      The FP data is sent in the Ch1-ch7 message. if that gets lost a lot, will not work. With the change to 22ms cycle in EdgeTX, FP is working 
      as expected.
    - Some FP responses are still getting lost, but the TX restransmit the command. This could be that the DSMP is only sending 1 telemetry package every 22ms, 
      but some spetrum RX can send 2 messages on that 22ms cycle (one every 11ms in DSMX mode).  This for sure will need change in the DSMP firmware.

2. Fix weird State after bind
    - Before was needed to restart TX to fix. Cause: Restarting the module twise at the same time..left it in weird state.

3. UI Fixes 
    - COLOR:  Show the Version of the DSMP module, as well as what protocol is currently using. Both Model->External, and System Info->Module
    - UI Fixes B&W.. Same as color
<img width="479" height="273" alt="image" src="https://github.com/user-attachments/assets/33258953-bc05-4524-ac93-702f62e6ad3e" />

4. Forward programming support.
    - DSMP v1 firmware:  so far, no good results.  
    - DSMP v2 firmware:  FP works as expected

5. Suport Ch order AETR -> TAER conversion.  
    - DSMP: All done in the TX, option on the module to turn on 
    AETR inputs, instead of the default TAER. The mode will show in 
    the status of the module.

6. TODO: Test PWM/PPM Interface

7. DSMP v2 firmware: Reseach option for bootloader, so that firmware can be updated from EdgeTX.

