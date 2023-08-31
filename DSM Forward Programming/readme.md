# Credits
Code is based on the code/work by: Pascal Langer (Author of the Multi-Module) 
Rewrite/Enhancements by: Francisco Arzu

Thanks to all the people volunteered to test it.

Please use:
- Color_480x272:  for Radiomaster TX16S or equivalent screen (480x272)
- Black_White:    (Beta Version for MINimal memory usage) for older radios (Smaller screens 128x64 and limited memory)
- In_Development: New code that is still in testing stages. Unless you want to help test it, don't use it yet.

## Message Files
We are constantly updating new messages who appear as "Unknown_XYZ" in the menus with the proper values.
You only have to update the message file `"msg_fwdp_en.txt"` inside `/SCRIPTS/TOOLS/DSMLIB` 

## Color Version
![main-menu](https://user-images.githubusercontent.com/32604366/230751340-dd118f36-1884-405b-b12b-81cba16c7321.png)
![flight-mode-setup](https://user-images.githubusercontent.com/32604366/230751281-0c71ff4a-179f-41fd-9290-302a6e0fe821.png)
![orientation](https://user-images.githubusercontent.com/32604366/230751350-59070e75-afa3-439b-8902-bc7b3b901084.png)
![wing-type](https://user-images.githubusercontent.com/32604366/230751370-b4e4355f-a3d2-4c44-aa1a-57861f1ff3da.png)



## Black & White Minimal version
This is running on a very memory limited FrSky QX7.  You can change the values, but unfortunatly, the code to setup a plane from zero is too big.
The memory is so tight, that depends on the EdgeTX firmware and compiled options

Sometimes the very first time, it does not run, since is doing Compile+Run..  Restart the radio and try again (already compiled, so it will run). 

V0.55 has a change to save a bit of  memory, is not loading ALL the aprox 400 menu messages to memory, but initially parse the file to find the message position in the file, and later when the menu is display, it load the messages for that menu from the SDCard. 


![IMG_3024](https://user-images.githubusercontent.com/32604366/230123260-614f4e5e-9546-4439-9196-db885894083f.jpg)
