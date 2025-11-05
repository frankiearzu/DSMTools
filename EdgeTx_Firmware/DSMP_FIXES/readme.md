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
5. Weird Movement after power cycle TX, while the RX is ON
    -   Was able to reproduce the problem.. is due to not having a setup message received before sending channels.
        FIXED in both EdgeTX and DSMP v2
6. DSMP Led Stays RED after binding. It does not go back to GREEN until you do a range test or TX restart.      
7. On some LemonRX receives, not getting telemetry with DSMP, but same RX works with MultiModule.
    -   Replicated with 1 old Gen2, but not with recent ones. 

<h2>EdgeTX changes as of Oct 25, 2025 (Serial LemonDSMP interface)</h2>

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

3. Servos move unexpectedly and servo Jitter at Startup for about 2 seconds.
    - If you have the RX ON before the TX, when the TX starts.. servo jumps.  Also this happen if you power cycle the TX while RX is on.
    - Really dangerous on electric Motors.. unexpected start for about 1-2s.
    - This is caused by the DSMP receiving channel data before the setup package.. The 1st setup package is lost during protocol discovery (PPM or Serial), so
      it takes about 2.2s to refresh again.
    - Partiall fixed.. during power on, is mostly solved, but when you change models, the servos still moves.. the only way to fix for all situations it is in the DSMP firmware code.

4. UI Fixes 
    - COLOR:  Show the Version of the DSMP module, as well as what protocol is currently using. Both Model->External, and System Info->Module
    - UI Fixes B&W.. Same as color
    - OLD firmware allowed you to change only the Initial channel and shift the end.. (Like Ch2-C13).. that did not make sense, 
    you want to edit the end Channel, not the start.
    - Suport Radio Ch order AETR (instead of default TAER). All done at the EdgeTX side. 

<img width="479" height="273" alt="image" src="https://github.com/user-attachments/assets/33258953-bc05-4524-ac93-702f62e6ad3e" />

5. Forward programming support.  This is the only thing that currently need new v2 module firmware.
    - DSMP v1 firmware:  so far, no good results.  
    - DSMP v2 firmware:  FP works as expected

6. Test PWM/PPM Interface on DSMP v2.. Seems to be working fine.

7. DSMP v2 firmware: Reseach option for bootloader, so that firmware can be updated from EdgeTX.

<h2>DSMP v2 changes/fixes</h2>

1. Reorganize code to make it more legible and mantainable.

2. Several code optimizations to remove duplicated code in a few places.

3. Support for Spektrum Forward programming

4. No more servo Jumping at startup or changing models. The firware waits for a setup-message AND channel data before sending channels out to the RF module.. Before, if it received a setup message first, it was sending to the RF channels with value of 0 or garbage (to one side).

5. Servo Jitter or Jump positions if a Channel Data message is received before the Setup Package. 
This was due that not all the global variables were properly initialized from EEPROM at statup. The setup package was correcting this. This was caused by having not having a perfect 4/7/4/7 timing.

6. Really good Frame transmission timing on the RF module. 4/7/4/7 (22ms cycle). The code originally is coded to depend on the TX to start the 22ms cycle, and it was not considering the processing time of building and sending the frames in the timing. So The frames was getting behind a bit incrementally, and thats the reason the last frame timing was off: 4.05/7.05/4.05/6.8.
Now the timing is the main driver of the code, and do any work in between the frames: serve serial port and telemetry.

8. DSMP LED will go back to GREEN after bind.
   
