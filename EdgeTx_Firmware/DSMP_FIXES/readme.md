<h1> EdgeTX Fixes For Lemon DSMP </h1> 

This firmware is from the branch 2.11, wich contains the latest is 2.11.3 + some other fixes that will become 2.11.4.. still not official to fly.



<h2>Oct 12, 2025</h2>

1. Change message/channels send cycle time from 11ms to 22ms..  DSMP is expecting to receive in 22ms cycles
    - This was causing 1 edgetx channel refresh message to be lost on every cycle
2. Fix weird State after bind
    - Before was needed to restart TX to fix. Cause: Restarting the module twise at the same time..left it in weird state.
3. UI Fixes 
    - COLOR:  Show the Version of the DSMP module, as well as what protocol is currently using. Both Model->External, and System Info->Module
    - UI Fixes B&W.. Same as color
4. Forward programming support.
    - DSMP v1 firmware:  so far, no good results.  
    - DSMP v2 firmware:  FP works as expected
6. TODO: Suport Ch order AETR -> TAER conversion.  
    - DSMP v1 firmware: can be done at the TX 
    - DSMP v2 firmware: could be supported by the v2 firmware

