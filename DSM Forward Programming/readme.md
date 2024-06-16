# Credits
Code is based on the code/work by: Pascal Langer (Author of the Multi-Module) 
Rewrite/Enhancements by: Francisco Arzu

Thanks to all the people volunteered to test it.

IMPORTANT: v0.57 is a workaround to problem on EdgeTX 2.10.x where LUA scripts writting to the /LOGS folder on some ocations can corrupt the /LOGS directiry  (you will see filenames with weird naming and garbage).
This version has writting to the logs turned OFF.  Besides that is the same as 0.57.
Make sure you delete your older /SCRIPTS/TOOLS/DSMLIB directory/folder when updating. You can delete the previous version (56, etc)

Please use:
- Color_480x272:  for Radiomaster TX16S or equivalent screen (480x272)
- Black_White:    MINimal memory usage for older radios (Smaller screens 128x64 and limited memory)
- In_Development: New code that is still in testing stages. Unless you want to help test it, don't use it yet.

## Message Files
With Spektrum constantly updating their firmware, if you see a messages who appear as "Unknown_XYZ", that means that the proper message need to be added to the message file. We try to keep the message file up to date. If you need to update it, You only have to update the message file `"msg_fwdp_en.txt"` inside `/SCRIPTS/TOOLS/DSMLIB`. The `"msg_fwdp_en.txt"` can be downloaded from the folders above (color or black&white)

## Color Version
![main-menu](https://user-images.githubusercontent.com/32604366/230751340-dd118f36-1884-405b-b12b-81cba16c7321.png)
![flight-mode-setup](https://user-images.githubusercontent.com/32604366/230751281-0c71ff4a-179f-41fd-9290-302a6e0fe821.png)
![orientation](https://user-images.githubusercontent.com/32604366/230751350-59070e75-afa3-439b-8902-bc7b3b901084.png)
![wing-type](https://user-images.githubusercontent.com/32604366/230751370-b4e4355f-a3d2-4c44-aa1a-57861f1ff3da.png)

![Heli1](https://github.com/frankiearzu/DSMTools/assets/32604366/acd64fa1-e926-4e9d-85ad-560f43659c88)
![Heli2](https://github.com/frankiearzu/DSMTools/assets/32604366/b36b8be4-8e09-4265-871e-e4bdae12ffda)

## Black & White Minimal version
Starting at V0.56, now you can setup completly planes from zero.  V0.55 was limited to only change some parameters.
There is still significant memory limitations in older radios, but i think with some tricks/restarts it will run on older radios. Please read the part "Dealing with memory problems".   Newer radios like the RM Boxter and TX12 Mk2 has more memory and should run without issues.

![image](https://github.com/frankiearzu/DSMTools/assets/32604366/be03ad40-3e2f-45e1-8f50-d231c3931169)
![image](https://github.com/frankiearzu/DSMTools/assets/32604366/5010a361-1234-4c83-97b2-2eb6ae0d1061)
![image](https://github.com/frankiearzu/DSMTools/assets/32604366/0d4e04dc-90d7-4322-9ad1-f57cbde49029)
![IMG_3024](https://user-images.githubusercontent.com/32604366/230123260-614f4e5e-9546-4439-9196-db885894083f.jpg)
