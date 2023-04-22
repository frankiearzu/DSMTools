# EdgeTx Firmware + TextGen

## NOTE: Official EdgeTX 2.8.3 NOW INCLUDES TextGen and GPS fix. No need to use the custom version any more.


The firmware listed here was build from a local branch with only one file changed to support Spektrum TextGen.  

This change is already in the nighly build towards v2.9.0 

The firmware was compiled from a local branch:
https://github.com/frankiearzu/edgetx/tree/v2.8.1_TextGen

- TextGen + Spektrum GPS:  Official EdgeTX 2.8.3 includes the Spektrum GPS fixes as well as TextGen (for Avian ESC programming). No need to use the custom version any more.
- Others:  Experimenting with new sensors (custom for some friends with the sensors before make the change officical).


## Radiomaster TX16S

File: `edgetx_TX16S_2.8.1_TextGen.bin` and `edgetx_TX16S_2.8.1_GPSFix5.bin`

Compiled from this local with the arguments:

`cmake -Wno-dev -DPCB=X10 -DPCBREV=TX16S -DBLUETOOTH=YES -DDEFAULT_MODE=2 -DGVARS=YES -DPPM_UNIT=US -DHELI=NO -DCMAKE_BUILD_TYPE=Release ../`

if you go to your System Radio information, in the version it will say "2.8.1-TextGen-selfbuild"

## FrSky QX7

File:
