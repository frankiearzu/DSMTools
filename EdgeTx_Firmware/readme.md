# EdgeTx Firmware + TextGen

The firmware listed here was build from a local branch with only one file changed to support Spektrum TextGen.  

This change is already in the nighly build towards v2.9.0 

The firmware was compiled from a local branch:
https://github.com/frankiearzu/edgetx/tree/v2.8.1_TextGen


## Radiomaster TX16S

File: `edgetx_TX16S_2.8.1_TextGen.bin`

Compiled from this local with the arguments:

`cmake -Wno-dev -DPCB=X10 -DPCBREV=TX16S -DBLUETOOTH=YES -DDEFAULT_MODE=2 -DGVARS=YES -DPPM_UNIT=US -DHELI=NO -DCMAKE_BUILD_TYPE=Release ../`

if you go to your System Radio information, in the version it will say "2.8.1-TextGen-selfbuild"

## FrSky QX7

File:
