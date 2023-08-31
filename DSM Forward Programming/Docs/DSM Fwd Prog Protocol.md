# Forward Programing Protocol

## Introduction
DSM, DSMX and DSM Forward Programming are propietary protocol from the **Spektrum** radio brand. Since they don't make this information public, we have to reverse engineer it by analyzing the data exchanged between the RX and TX.

This document descrives what we know so far.

Thanks to **Pascal Langer** (Author of the Multi-Module) for the initial reverse engineering of the protocol and first version of the code that has been used for a while (Version 0.2)

Thanks to **Francisco Arzu** for taking the time to continue the work on reverse engineering, documenting and making the code more understandable.


# Menu Title and Lines

The menu to be displayed is stored at the RX, the GUI only renders the menu title and menu lines received. The tipical conversation with the RX will be to ask for a menu (using the menuId number), and then wait for the data to come. The first thing will be the Menu (header) data, later we request the next 6 lines (one at a time), and optionally the values for each line.

A typical exchange will look like this in the log:

    SEND DSM_getMenu(MenuId=0x1010 LastSelectedLine=0)
    RESPONSE Menu: M[Id=0x1010 P=0x0 N=0x0 B=0x1000 Text="Gyro settings"[0xF9]]
    SEND DSM_getFirstMenuLine(MenuId=0x1010)
    RESPONSE MenuLine: L[#0 T=M VId=0x1011 Text="AS3X Settings"[0x1DD]   MId=0x1010 ]
    SEND DSM_getNextLine(MenuId=0x1010,LastLine=0)
    RESPONSE MenuLine: L[#1 T=M VId=0x1019 Text="SAFE Settings"[0x1E2]   MId=0x1010 ]
    SEND DSM_getNextLine(MenuId=0x1010,LastLine=1)
    RESPONSE MenuLine: L[#2 T=M VId=0x1021 Text="F-Mode Setup"[0x87]   MId=0x1010 ]
    SEND DSM_getNextLine(MenuId=0x1010,LastLine=2)
    RESPONSE MenuLine: L[#3 T=M VId=0x1022 Text="System Setup"[0x86]   MId=0x1010 ]

## Menu 

The menu has the following information:

    Menu: M[Id=0x1010 P=0x0 N=0x0 B=0x1000 Text="Gyro settings"[0xF9]]

- `MenuId`: The menu ID number of the menu (hex, 16 bit number)
- `PrevId`: The menu ID of the previous menu (for navigation), Log show as `"P="`
- `NextId`: The menu ID of the next menu (for navigation), Log shows as `"N="`
- `BackId`: The menu ID of the back menu (for navigation), Log shows as `"B="`
- `TextId`: The message number to display (16 bits, Hex). Log shows as [`0xXX`] after the message.  
- `Text`: Retrived using the `TextId` from the script message `Text` array.

## Menu Lines

The menu lines has the following information:

    L[#0 T=V_nc VId=0x1000 Text="Flight Mode"[0x8001] Val=1 [0->10,0] MId=0x1021 ]
    L[#1 T=M VId=0x7CA6 Text="FM Channel"[0x78]   MId=0x1021 ]
    L[#2 T=LM VId=0x1002 Text="AS3X"[0x1DC] Val=1|"Act" NL=(0->1,0,S=3) [3->4,3] MId=0x1021 ]

-  `MenuId`: of the menu they beling to. Log show as `"MId="` at the end.
-  `LineNum`: Line number (0..5). The line number in the screen. Log show as # in the beginning
-  `Type`: Type of Line, Log shows as `"T="`  (explanation later)
-  `TextId`: The message number to display (16 bits, Hex). Log shows as [`0xXXXX`] after the message.  
-  `Text`:  Retrived using the `TextId` from the script message `Text` array.
-  `ValueId`: The value or menu ID of the line. Log shows as `"VId="` (16 bits, Hex).
-  `Value Range`: Shows as [`Min`->`Max`, `Default`]. This is the RAW data comming from the RX
-  `NL`: Computed Normalized LIST (0 reference) for List Values. Source is the RAW range. For example, for lines of list of values.   `[3->4,3]` is tranlated to `NL=(0->1,0,S=3)` since the value is also normalize to 0. `"S="` means the initial entry in the `List_Text` array
-  `Val`: Current value for line who hold data. Relative to 0 for List Values. For List Values, the log will show the translation of the value to display text. example: `Val=1|"Act"` that is coming from `List_Value[4]`

## Type of Menu Lines

-   `LINE_TYPE.MENU (Log: "T=M")`: This could be regular text or a navigation to another menu. if `ValueId` is the same as the current MenuId (`MId=`), is a plain text line (navigation to itself).  If the `ValueId` is not the current menuId, then `ValueId` is the MenuId to navigate to.  

    We have found only one exception to the plain text rule, a true navigation to itself, in that case, in the text of the menu, you can use the "/M" flag at the end of the text to force it to be a menu button. 

        Example, FM_Channel is a navigation to menuId=0x7CA6.

        L[#1 T=M VId=0x7CA6 Text="FM Channel"[0x78]   MId=0x1021 ]

-   `LINE_TYPE.LIST_MENU_NC (Log T=LM_nc)`:  This is a line that shows as text in the GUI. The numeric value is translated to the proper text. The range is important, since it descrives the range of posible values. No incremental RX changes, only at the end.

        Example: List of Values, List_Text[] starts at 53, ends at 85, with a default of 85. When normalized to 0, is a range from 0->32 for the numeric value. The Display value `Aux1` is retrive from `List_Text[6+53]`.

        L[#0 T=LM_nc VId=0x1000 Text="FM Channel"[0x78] Val=6|"Aux1" NL=(0->32,0,S=53) [53->85,53] MId=0x7CA6 ]

 -  `LINE_TYPE.LIST_MENU_TOG (Log T=L_tog)`: Mostly the same as LIST_MENU_NC, but is just 2 values. (ON/OFF, Ihn/Act, etc). Should be a toggle in the GUI.

        L[#2 T=LM_tog VId=0x1002 Text="AS3X"[0x1DC] Val=1|"Act" NL=(0->1,0,S=3) [3->4,3] MId=0x1021 ]

-  `LINE_TYPE.LIST_MENU (Log T=LM)`: Mostly the same as LIST_MENU_NC, but incremental changes to the RX. Some times, it comes with a strange range `[0->244,Default]`. Usually this means that the values are not contiguos range; usually Ihn + Range. Still haven't found where in the data the correct range comes from. 

        Example: Valid Values: 3, 176->177 (Inh, Self-Level/Angle Dem, Envelope)
        L[#3 T=LM VId=0x1003 Text="Safe Mode"[0x1F8] Val=176|"Self-Level/Angle Dem" NL=(0->244,3,S=0) [0->244,3] MId=0x1021 ]

-   `LINE_TYPE.VALUE_NUM_I8_NC (Log: "T=V_nc")`: This line is editable, but is not updated to the RX incrementally, but only at the end. The Flight Mode line is of this type, so we have to check the TextId to differenciate between Flight mode and an Editable Value.  
Fligh Mode TextId is between 0x8000 and 0x8003

        Example, Flight mode comes from Variable ValId=0x1000, with current value of 1. Range of the Value is 0..10.

        L[#0 T=V_nc VId=0x1000 Text="Flight Mode"[0x8001] Val=1 [0->10,0] MId=0x1021 ]


-   `LINE_TYPE.VALUE_NUM_I8 (Log T=V_i8)`:  8 bit number (1 byte) 
-   `LINE_TYPE.VALUE_NUM_I16' (Log T=V_i16)`: 16 Bit number (2 bytes)
-   `LINE_TYPE.VALUE_NUM_SI16 (Log T=V_si16)`: Signed 16 bit number (2 bytes) 
-   `LINE_TYPE.VALUE_PERCENT (Log T=L_%)`: Shows a Percent Value. 1 Byte value.
 -  `LINE_TYPE.VALUE_DEGREES (Log T=L_de)`: Shows a Degrees VAlue. 1 Byte value.


## LIST_TYPE Bitmap
TYPE|Sum|Hex|7 Signed|6 Valid Min/Max??|5 No-Inc-Changing|4 Menu|3 List-Menu|2 text / number|1|0 - 16 bits
|-|-|-|-|-|-|-|-|-|-|-
|MENU|Text|0x1C|0|0|0|1|1|1|0|0
|LIST_MENU|Text|0x0C|0|0|0|0|1|1|0|0
|LIST_MENU_TOG|Text|0x4C|0|1|0|0|1|1|0|0
|LIST_MENU_NC|Text, NC|0x6C|0|1|1|0|1|1|0|0
|VALUE_NUM_I8_NC|I8, NC|0x60|0|1|1|0|0|0|0|0
|VALUE_PERCENT|S8|0xC0|1|1|0|0|0|0|0|0
|VALUE_DEGREES|S8 NC|0xE0|1|1|1|0|0|0|0|0
|VALUE_NUM_I8|I8|0x40|0|1|0|0|0|0|0|0
|VALUE_NUM_I16|I16|0x41|0|1|0|0|0|0|0|1
|VALUE_NUM_SI16|S16|0xC1|1|1|0|0|0|0|0|1


## Important Behavioral differences when updating values

Values who are editable, are updated to RX as they change. For example, when changing attitude trims, the servo moves as we change the value in real-time.

LIST_MENU_NC, VALUE_NUM_I8_NC don't update the RX as it changes. It changes only in the GUI, and only update the RX at the end when confirmed the value.  (NO-INC-CHANGES Bit)

After finishing updating a value, a validation command is sent. RX can reject the current value, and will change it to the nearest valid value.

## Special Menus

Seems like menuId=0x0001 is special. When you navigate to this menu, the RX reboots.
When this happens, we need to start from the beginning as if it was a new connection.

# Send and Receive messages

To comunicate with the Multi-Module, Lua scripts in OpenTx/EdgeTx has access to the `Multi_Buffer`. Writting to it will send data to RX, received data will be read from it.

For our specific case, this is how the Multi_Buffer is used:

|0..2|3|4..9|10..25
|--|--|--|--
|DSM|0x70+len|TX->RX data|RX->TX Data

To write a new DSM Fwd Programing command, write the data to address 4..9, and later set the address 3 with the length.  

When receiving data, address 10 will have the message type we are receiving, or 0 if nothing has been received.

## Starting a new DSM Forward programming Connection 

- Write 0x00 at address 3
- Write 0x00 at address 10
- Write "DSM" at address 0..2

## Disconnect

- Write 0x00 at address 0


# Request Messages (TX->RX)
The first byte is the message type, the 2nd byte is the entire length starting from the message type. Example:

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg| Len | D1 | D2 
0x00|0x04|0x00|0x00


## DSM_sendHeartbeat()
keep connection open.. We need to send it every 2-3 seconds, otherwise the RX will force close the connection by sending the TX an Exit_Confirm message.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg| Len | ?? | ?? 
0x00|0x04|0x00|0x00
    
    SEND DSM_sendHeartbeat()
    DSM_SEND: [00 04 00 00 ]

 ## DSM_getRxVersion()
Request the RX information.
TXCh is the number of channels sent by the TX after CH6. For example, 0=6Ch,2=8ch,6=12Ch.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg| Len | TXCh | ?? |??|??
0x11|0x06|0x06|0x14|0x00|0x00

    SEND DSM_getRxVersion() 
    DSM_SEND: [11 06 06 14 00 00 ]

## DSM_getMainMenu()
Request data for the main menu of the RX.
TXCh (See getRXVersion).
The RX will request information about all the channels reported by the TX via
`RequestTXChInfo`.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg| Len | TXCh | ?? |??|??
0x12|0x06|0x06|0x14|0x00|0x00

    SEND DSM_getMainMenu()
    DSM_SEND: [12 06 06 14 00 00 ]


## DSM_getMenu(menuId, lastSelLine)
Request data for Menu with ID=`menuId`. `lastSelLine` is the line that was selected to navigate to that menu.

When navigating via BACK, PREV, NEXT use 0x80, 0x81, and 0x82.  This is specially important on some menus who stores captured data.. without them, they don't save the data (Attitude trim, RX orientation)

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (menuId) | LSB (MenuId) | MSB (lineNo)| LSB (lineNo)
0x16|0x06|0x10|0x60|0x00|0x01

    SEND DSM_getMenu(MenuId=0x1060 LastSelectedLine=1)
    DSM_SEND: [16 06 10 60 00 01 ]

## DSM_getFirstMenuLine(menuId)
Request the first line of a menu identified as `menuId`. The response will be the first line of the menu. 

On the MainMenu, it will start requesing TxChannel info only the very first time before start sending the menu lines.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (menuId) | LSB (MenuId) 
0x13|0x04|0x10|0x60

    SEND DSM_getFirstMenuLine(MenuId=0x1000)
    DSM_SEND: [13 04 10 00 ]

## DSM_getNextMenuLine(menuId, curLine)
Request the retrival of the next line following the current line. Response is either the next line, or the next value, or nothing.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (menuId) | LSB (MenuId) | MSB (line#)??| LSB (line#)
0x14|0x06|0x10|0x60|0x00|0x01

    SEND DSM_getNextLine(MenuId=0x1000,LastLine=1)
    DSM_SEND: [14 06 10 00 00 01 ]

##  DSM_getNextMenuValue(menuId, valId)
Retrive the next value after the last `ValId` of the current `menuId`.  text is just for debugging purposes to show the header of the value been retrived.
The Response is a Menu Value or nothing if no more data.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (menuId) | LSB (MenuId) | MSB (ValId)| LSB (ValId)
0x15|0x06|0x10|0x61|0x10|0x00

    SEND DSM_getNextMenuValue(MenuId=0x1061, LastValueId=0x1000) 
    DSM_SEND: [15 06 10 61 10 00 ]

## DSM_updateMenuValue(valId, val)
Updates the value identified as `valId` with the numeric value `val`. 

If the value is negative, it has to be translated to the proper DSM negative representaion.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (ValId) | LSB (ValId) | MSB (Value)| LSB (Value)
0x18|0x06|0x__|0x__|0x__|0x__

    DSM_updateMenuValue(valId, value)
    -->DSM_send(0x18, 0x06, int16_MSB(valId), int16_LSB(valId), int16_MSB(value), int16_LSB(value)) 

## DSM_validateMenuValue(valId)
Validates the value identified as `valId`. The RX can response an Update value if the value is not valid and needs to be corrected.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (ValId) | LSB (ValId)
0x19|0x06|0x__|0x__


    DSM_validateMenuValue(valId)
    -> DSM_send(0x19, 0x06, int16_MSB(valId), int16_LSB(valId)) 

## DSM_menuEditingValue(lineNo) 
During editing, we need to tell the RX that we are editing a line (LineNo is zero base).. This will lock the screen to any changes of flight mode.  If we are editing a value that represents channel, this will "listen" to Channel changes and populate the value if a swith is flipped.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (Line#) | LSB (Line#)
0x1A|0x04|0x__|0x__

    DSM_menuEditingValue(lineno)
    ->DSM_send(0x1A, 0x06, int16_MSB(lineNo), int16_LSB(lineNo))


## DSM_menuEditingValueEND(lineNo) 
This tells the RX that we are done editing a line.
.
|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | MSB (Line#) | LSB (Line#)
0x1B|0x04|0x__|0x__

    DSM_menuEditingValueEND(lineno)
    ->DSM_send(0x1B, 0x06, int16_MSB(lineNo), int16_LSB(lineNo))


## DSM_exitRequest()
Request to end the DSM Frd Prog connection. Will reponse with an exit confirmation.

|4|5|6|7|8|9|10
|--|--|--|--|--|--|--
Msg|Len | 
0x1F|0x02|

    CALL DSM_exitRequest()
    DSM_SEND: [1F 02 ]

# Response Messages (RX->TX)

All responses will have the a response byte in Multi_Buffer[10]=0x09 (I2C_FORMARD_PROG value 0x09), and the type of message in Multi_Buffer[11].

## RX Version Response

Returns the information about the current RX.

The Display text of name name of the RX is retrive from the `RX_Name` array.

|10|11|12|13|14|15|16
|--|--|--|--|--|--|--
|Resp|Msg|?? |RxId|Major|Minor|Patch
|0x09|0x01|0x00|0x1E|0x02|0x26|0x05

    RESPONSE RX: 09 01 00 1E 02 26 05 
    RESPONSE Receiver=AR631 Version 2.38.5

## Menu Response
Returns the menu information to display and navigation.
The Display text for the menu is retrive from the `Text` array.


|10|11|12|13|14|15|16|17|18|19|20|21
|--|--|--|--|--|--|--|--|--|--|--|--
|Resp|Msg|LSB (menuId)|MSB (menuId)|LSB (TextId)|MSB (TextId)|LSB (PrevId)|MSB (PrevId)|LSB (NextId)|MSB (NextId)|LSB (BackId)|MSB (BackId)
|0x09|0x02|0x5E|0x10|0x27|0x02|0x00|0x00|0x00|0x00|0x00|0x10

    RESPONSE RX: 09 02 5E 10 27 02 00 00 00 00 00 10 00 00 00 00 
    RESPONSE Menu: M[Id=0x105E P=0x0 N=0x0 B=0x1000 Text="Other settings"[0x227]]



## Menu Line Response
Returns the menu line information.

The Display text for the menu line is retrive from the `Text` array.
 `Min`,`Max` and `Default` can be signed numbers.

|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25
|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--
|Resp|Msg|LSB (menuId)|MSB (menuId)|Line#|Line Type|LSB (TextId)|MSB (TextId)|LSB (ValId)|MSB (ValId)|LSB (Min)|MSB (Min)|LSB (Max)|MSB (Max)|LSB (Def)|MSB (Def)
|0x09|0x03|0x61|0x10|0x00|0x6C|0x50|0x00|0x00|0x10|0x36|0x00|0x49|0x00|0x36|0x00

    RESPONSE RX: 09 03 61 10 00 6C 50 00 00 10 36 00 49 00 36 00 
    RESPONSE MenuLine: L[#0 T=LM_nc VId=0x1000 Text="Outputs"[0x50] Val=nil NL=(0->19,0,S=54) [54->73,54] MId=0x1061 ]

## Menu Line Value Response
Returns the Value for a line. 

The response updates the Value in the line identified by `ValId`.
The Display text for the Value, when it is a list, is retrive from the `List_Text` array.

|10|11|12|13|14|15|16|17
|--|--|--|--|--|--|--|--
|Resp|Msg|LSB (menuId)|MSB (menuId)|LSB (ValId)|MSB (ValId)|LSB (Value)|MSB (Value)
|0x09|0x04|0x61|0x10|0x00|0x10|0x00|0x00

    RESPONSE RX: 09 04 61 10 00 10 00 00 
    RESPONSE MenuValue: UPDATED: L[#0 T=L_m0 VId=0x1000 Text="Outputs"[0x50] Val=0|"Throttle" NL=(0->19,0,S=54) [54->73,54] MId=0x1061 ]

## Exit Response
Response from a Exit Request.

|10|11
|--|--
|Resp|Msg
|0x09|0x07

    RESPONSE RX: 09 A7  
    RESPONSE Exit Confirm

## NULL Response (HeartBeat)
Can be use as a response, or heartbeat from the RX to keep the connection open.

|10|11
|--|--
|Resp|Msg
|0x09|0x00

    RESPONSE RX: 09 00  
    RESPONSE NULL


# Request TX Info  (RX requesting TX info)

The RX is requesting information about the TX.
The flight controller/RX needs to know what channels are used for Flying surfaces and throttle, as well as servo settings in the TX for that channels.


## DSM_getTXChInfo(menuId, Ch)

Request the info of the specific `Ch` (0 based).
`InfoType`: 
0x00 = Basic + Travel + END
0x01 = Basic 
0x1F = Basic + Travel + SubTrim + 0x24 + END

|10|11|12|13
|--|--|--|--
|Resp|Msg|Ch#|InfoType
|0x09|0x05|0x00|0x01

    RESPONSE RequestTXChInfo: 09 05  
    RESPONSE NULL


## Message 0x20 Response: Basic Channel Role info

Role1: MixType
Role2: UsageType-Bits


| 4| 5| 6| 7| 8| 9
|--|--|--|--|--|--
Msg|Len | Ch# | Ch# | Role1 | Role2 
0x20|0x06|0x00|0x00|0x00|0x40 

### UsageType-Bits

|MASK|Meaning
|--|--
|0x01|Ail
|0x02|Elv
|0x04|Rud
|0x40|Thr
|0x20|Reversed
|0x80|Slave  (2nd use of same surface)

### Mix Bits
Seems that Reverse do a complement of the first 3 bits Mix

|MASK|Bits | Meaning| Comment
|--|--|--|--
|0x00| 0000| Normal|
|0x10| 0001| MIX_AIL_B| Taileron 
|0x20| 0010| MIX_ELE_A| For VTail and Delta-ELEVON A
|0x30| 0011| MIX_ELE_B_REV | For VTIAL and Delta-ELEVON B
|0x40| 0100| MIX_ELE_B| For VTIAL and Delta-ELEVON B
|0x50| 0101| MIX_ELE_A_REV | For VTIAL and Delta-ELEVON A
|0x60| 0110| MIX_AIL_B_REV| Taileron  Rev
|0x70| 0111| NORM_REV | Reversed

## Message 0x21 Response: SubTrim info  (Range)

Sends the Left and Right values of the Servo Range (0-2047)

Initial "Center" with 100% travel, 0-Subtrim is (142-1906)

For Every % of travel relative 100, open the range (* 8.8). For example, 101% is (136-1914).

For Every Subtrim number, move the range left/right (*2). For example, a Subtrim of 1, is (144-1908)

if the left value is < 0, use 0.  is the right is > 2047, use 2047.


| 4| 5| 6| 7| 8| 9 | 10
|--|--|--|--|--|--|--
Msg|Len | Ch# | MSB(left) | LSB(left) | MSB(right) | LSB (right) 
0x21|0x06|0xCH|0xLL|0xLL|0xRR|0xRR

## Message 0x22: Ch Info END
Sent when there is no more data for the Ch for multi-line information.
No channel referenced in the response.

| 4| 5| 6| 7
|--|--|--|--
Msg|Len | 0x00| 0x00 
0x22|0x04|0x00|0x00


## Message 0x23 Response: Servo Travel (Percent)

Percent of travel to left and right.  
Only positive numbers between 0-150%


| 4| 5| 6| 7| 8| 9 | 10
|--|--|--|--|--|--|--
Msg|Len | Ch# | MSB(left) | LSB(left) | MSB(right) | LSB (right) 
0x23|0x06|0xCH|0xLL|0xLL|0xRR|0xRR

## Message 0x24: Unknown, 

Same data for every channel. No channel referenced in the reponse


DSM_send(0x24, 0x06, 0x00, 0x83, 0x5A, 0xB5)

DSM_send(0x24, 0x06, 0x06, 0x80, 0x25, 0x4B) 


