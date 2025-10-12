<h1> EdgeTX Fixes For Lemon DSMP </h1> 

This firmware is from the branch 2.11, wich contains the latest is 2.11.3 + some other fixes that will become 2.11.4.. still not official to fly.


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

<h2>EdgeTX changes Oct 12, 2025 (Serial LemonDSMP interface)</h2>

1. Change message/channels send cycle time from 11ms to 22ms..  DSMP is expecting to receive in 22ms cycles
    - This was causing 1 edgetx channel refresh message to be lost on every cycle
    - Probaly not as critical in normal use, since all channels will eventually get refreshed, but at one time, one of my channels froze for about 
      2s, that could be explained by loosing the message consistently for a bit. 1 message for ch1-6, and another 
      for ch7-12, at 2.2s, an extra status message is send, so it changes the order.. now ch7-12 first, then ch1-6;

2. Fix weird State after bind
    - Before was needed to restart TX to fix. Cause: Restarting the module twise at the same time..left it in weird state.

3. UI Fixes 
    - COLOR:  Show the Version of the DSMP module, as well as what protocol is currently using. Both Model->External, and System Info->Module
    - UI Fixes B&W.. Same as color

4. Forward programming support.
    - DSMP v1 firmware:  so far, no good results.  
    - DSMP v2 firmware:  FP works as expected

5. TODO: Test PWM/PPM Interface

6. TODO: Suport Ch order AETR -> TAER conversion.  
    - DSMP v1 firmware: can be done at the TX 
    - DSMP v2 firmware: could be supported by the v2 firmware

7. DSMP v2 firmware: Reseach option for bootloader, so that firmware can be updated from EdgeTX.

