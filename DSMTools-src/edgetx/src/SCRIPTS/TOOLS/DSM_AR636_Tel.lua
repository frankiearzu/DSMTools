local toolName = "TNS|DSM AR636 Tel v1.1|TNE"
---- #########################################################################                                                                  #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

------------------------------------------------------------------------------ 
-- Developer: Francisco Arzu
-- Original idea taken from DsmPID.lua.. don't know who is the author 
-- 

local DEBUG_ON = false
--

local TEXT_SIZE             = 0 -- NORMAL
local TEXT_SIZE_BIG         = MIDSIZE

local X_COL1_HEADER         = 6
local X_COL1_DATA           = 60
local X_COL2_HEADER         = 170
local X_COL2_DATA           = 220
local Y_LINE_HEIGHT         = 20
local Y_HEADER              = 0
local Y_DATA                = Y_HEADER + Y_LINE_HEIGHT*2 
local X_DATA_LEN            = 80 
local X_DATA_SPACE          = 5


local U8_NODATA             = 0xFF
local U16_NODATA            = 0xFFFF
local U32_NODATA            = 0xFFFFFFFF
local I8_NODATA             = 0x7f
local I16_NODATA            = 0x7fff

local STR_data              = {[0]=0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF, 0xFF, 0x0FF}

local I2C_TEXT_GEN          = 0x0C
local I2C_ALPHA6_GAINS      = 0x1E
local I2C_LEGACY_AS3X       = 0x1F
local I2C_ALPHA6_MONITOR    = 0x24
local I2C_QOS               = 0x7F 

local function Unsigned_to_SInt16(value) 
  if value >= 0x8000 then  -- Negative value??
      return value - 0x10000
  end
  return value
end

local function STR_open(i2cId)
  --Init telemetry  (Spectrun Telemetry Raw STR)
  for i=0,15 do
    STR_data[i] = U8_NODATA
  end

  multiBuffer( 0, string.byte('S') )
  multiBuffer( 1, string.byte('T') )
  multiBuffer( 2, string.byte('R') ) 
  multiBuffer( 3, i2cId ) -- Monitor this teemetry data
  multiBuffer( 4, 0 ) -- Allow to get Data
end

local function STR_close()
  multiBuffer(0, 0) -- Destroy the STR header 
  multiBuffer(3, 0) -- Not requesting any Telementry ID
end

local function STR_isDataReady(i2cId) 
  if (multiBuffer(0)~=string.byte('S') or multiBuffer(3) ~= i2cId ) then -- First time run???
    STR_open(i2cId) -- I2C_ID 
  end

  if multiBuffer( 4 ) == i2cId then
    for i=0,15 do
      STR_data[0+i] = multiBuffer(4+i)
    end
    multiBuffer( 4, 0 ) -- Allow to get Data
    return true
  end
  return false
end

local function STR_DATA_U8(p)
  local val = STR_data[p]
  if (val == U8_NODATA) then return nil else return val end
end

local function STR_DATA_U16(p)
  local val = bit32.lshift(STR_data[p], 8) + STR_data[p+1]
  if (val == U16_NODATA) then return nil else return val end
end

local function STR_DATA_I16(p)
  local val = STR_data[p+1] + bit32.lshift(STR_data[p], 8)
  if (val == I16_NODATA) then return nil else return Unsigned_to_SInt16(val) end
end

local function STR_Disp(val, postfix)
  if (val == nil) then return "---" end
  return val .. (postfix or "")
end

local function STR_DispFloat1(val,postfix)
  if (val == nil) then return "---" end
  return string.format("%0.1f",val/10) .. (postfix or "")
end

local function STR_DispFloat2(val,postfix)
  if (val == nil) then return "---" end
  return string.format("%0.2f",val/100) .. (postfix or "")
end

-----------------------------------------------------------------------------------

local function drawPIDScreen()
  local function getPage(iParam)
    -- get page from 0-based index
    -- {0,1,2,3}: cyclic (1), {4,5,6,7}: tail (2)
    local res = (math.floor(iParam/4)==0) and 0 or 1
    return res
  end

  -- draw labels and params on screen
  local A = STR_DATA_U16(2) or 0 --A
  local B = STR_DATA_U16(4) or 0 --B 
  local L = STR_DATA_U16(6) or 0 --L 
  local R = STR_DATA_U16(8) or 0 --R  
  local F = STR_DATA_U16(10) or 0 -- F
  local H = STR_DATA_U16(12) or 0 -- H


  local pageId = F
  
  lcd.clear()
  lcd.drawText(1,0,"BLADE Gain Adjustment", TEXT_SIZE +INVERS)
  -- if active gain does not validate then assume
  -- Gain Adjustment Mode is disabled
  if not (pageId==4401 or pageId==4402) then return end

  local activePage = (pageId % 100)-1  --Last 2 digits, make it zero base 

  lcd.drawText (X_COL1_HEADER, Y_DATA, "Cyclic (0-200)", TEXT_SIZE + INVERS)
  lcd.drawText (X_COL2_HEADER, Y_DATA, "Tail (0-200)", TEXT_SIZE + INVERS)

  local titles = {[0]="P:", "I:", "D:", "Resp:", "P:","I:","D:", "Filt:"}
  local values = {[0]=A,B,L,R,A,B,L,R}

  local activeParam =  (H - 1)

  for iParam=0,7 do
    -- highlight selected parameter
    local attr = (activeParam==iParam) and INVERS or 0
    -- circular index (per page)
    local perPageIndx = (iParam % 4)
    
    -- set y draw coord
    local y = (perPageIndx+2)*Y_LINE_HEIGHT+Y_DATA
    
    -- check if displaying cyclic params.
    local isCyclicPage = (getPage(iParam)==0)

    -- labels
    local x = isCyclicPage and X_COL1_HEADER or X_COL2_HEADER
    -- labels are P,I,D for both pages except for last param
    local val = titles[iParam]
    lcd.drawText (x, y, val, TEXT_SIZE)
    
    -- gains
    -- set all params for non-active page to '--' rather than 'last value'
    val = (getPage(iParam)==activePage) and values[iParam] or '--'
    x = isCyclicPage and X_COL1_DATA or X_COL2_DATA

    if (val~=0x4000) then  -- Active value
      lcd.drawText (x, y, val, attr + TEXT_SIZE)
    end
  end
end

-----------------------------------------------------------------------------------

local function servoAdjustScreen()
  local A = STR_DATA_U16(2) or 0 --A
  local B = STR_DATA_U16(4) or 0 --B 
  local L = STR_DATA_U16(6) or 0 --L 
  local R = STR_DATA_U16(8) or 0 --R  
  local F = STR_DATA_U16(10) or 0 -- F
  local H = STR_DATA_U16(12) or 0 -- H


  -- draw labels and params on screen
  local pageId = F -- FLss  
  local activeParam = H - 1 -- Hold 
  
  lcd.clear()
  lcd.drawText (1, Y_HEADER, "BLADE Servo SubTrim", TEXT_SIZE + INVERS)

  if pageId~=1234 then return end

  local titles  = {[0]="S1:", "S2:", "S3:"}
  local values  = {[0]=A,B,L}

  for iParam=0,#values do   -- S1,S2,S3 
    -- highlight selected parameter
    local attr = (activeParam==iParam) and INVERS or 0

    -- set y draw coord
    local y = (iParam+1)*Y_LINE_HEIGHT+Y_HEADER + Y_LINE_HEIGHT
    
    -- labels
    lcd.drawText (X_COL1_HEADER, y,  titles[iParam], TEXT_SIZE)
    
    local val = values[iParam] 
    if (val~=0x4000) then  -- Active value
      -- Subtrim value is shifted by 1000
      lcd.drawText (X_COL1_DATA, y, val-1000, attr + TEXT_SIZE)
    end
  end
end

-----------------------------------------------------------------------------------

local function bladeAdjustScreen()
  STR_isDataReady(I2C_QOS)
  local F = STR_DATA_U16(10) or 0 -- F

  local pageId = F -- F 
  if (pageId==4401 or pageId==4402) then
    drawPIDScreen()
  elseif (pageId==1234) then
    servoAdjustScreen()
  else
    lcd.clear()
    lcd.drawText (1, Y_HEADER, "BLADE Adjustments", TEXT_SIZE + INVERS)

    lcd.drawText(X_COL1_HEADER,Y_LINE_HEIGHT*1,"Enter Servo Adjustment Mode",TEXT_SIZE)
    lcd.drawText(X_COL1_HEADER,Y_LINE_HEIGHT*2,"Stk: (D/L) + (D/R) + Panic (3 sec)",TEXT_SIZE)

    lcd.drawText(X_COL1_HEADER,Y_LINE_HEIGHT*4,"Enter Gain Adjustment Mode",TEXT_SIZE)
    lcd.drawText(X_COL1_HEADER,Y_LINE_HEIGHT*5,"Stk: (D/R) + (D/R) + Panic (3 sec)",TEXT_SIZE)
    
    lcd.drawText(X_COL1_HEADER,Y_LINE_HEIGHT*7,"Op: Right Stk:  U/D to select, L/R change value",TEXT_SIZE)
    lcd.drawText(X_COL1_HEADER,Y_LINE_HEIGHT*8,"Panic (3 sec) to exit",TEXT_SIZE)
  end
end

-----------------------------------------------------------------------------------

local function drawVersionScreen()
  STR_isDataReady(I2C_QOS)

  local paramV  =  STR_DATA_U16(2) or 0 --A
  local B       =  STR_DATA_U16(4) or 0 --B 
  local rxId    =  STR_DATA_U16(6) or 0 --L 
  local firmware = STR_DATA_U16(10) or 0 --F   
  local prodId  =  STR_DATA_U16(12) or 0 -- H

  local bat     =  getValue("A2") or 0
  
  lcd.clear()
  lcd.drawText (1, Y_HEADER, "BLADE Version", TEXT_SIZE + INVERS)

  --Product ID
  local val = "ID_".. prodId

  if (prodId==243) then val = "Blade 230 V1"
  elseif (prodId==250) then val = "Blade 230 V2 (not Smart)" 
  elseif (prodId==149) then val = "Blade 250 CFX" 
  end

  local y = Y_DATA
  local x_data1 = X_COL1_DATA+X_DATA_LEN
  lcd.drawText (X_COL1_HEADER, y, "Prod:", TEXT_SIZE)
  lcd.drawText (x_data1, y, val,  TEXT_SIZE)

  -- RX
  val = "ID_"..rxId
  if (rxId==1) then val = "AR636" end

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER, y, "RX:", TEXT_SIZE)
  lcd.drawText (x_data1, y, val,  TEXT_SIZE)

  -- Firmware
  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER, y, "Firmware:", TEXT_SIZE)
  lcd.drawText (x_data1, y, STR_DispFloat2(firmware),  TEXT_SIZE)

  -- ParamV
  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER, y, "Params:", TEXT_SIZE)
  lcd.drawText (x_data1, y, paramV,  TEXT_SIZE)

  -- Bat
  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER, y, "Bat:", TEXT_SIZE)
  lcd.drawText (x_data1, y, string.format("Bat: %0.2f V",bat),  TEXT_SIZE)

  y = y + Y_LINE_HEIGHT
  lcd.drawText(X_COL1_HEADER,y,"Press Panic for 3s",TEXT_SIZE)

  y = y + Y_LINE_HEIGHT
  lcd.drawText(X_COL1_HEADER,y,"Usually Panic is Ch7 on a switch and Revesed",TEXT_SIZE)

end

-----------------------------------------------------------------------------------

local function parseAlpha6FM(v)
  -- FlightMode   (Hex:  MS)  M=Flight Mode, S=Status (0=boot, 1=init, 2=Ready/Hold, 3=Sensor Fault, 4=Power Fault)
  if v==nil then return "---" end
  local fm = bit32.rshift(v, 4)
  local status = bit32.band(v,0xF)

  local res = " "..fm.."  "

  if (fm==0) then res = res .. " NORMAL" 
  elseif (fm==1) then res = res .. " INTERMEDIATE" 
  elseif (fm==2) then res = res .. " ADVANCED" 
  elseif (fm==5) then res = res .. " PANIC" 
  end

  if (status==2) then res=res .. "    HOLD" end

  return res
end

-----------------------------------------------------------------------------------

local function drawAlpha6Monitor()
  if event == EVT_VIRTUAL_EXIT then -- Exit?? Clear menu data
    STR_close()
    return
  end

  -- Proces Telementry message
  STR_isDataReady(I2C_ALPHA6_MONITOR)

  lcd.clear()

  local bat =  getValue("A2") or 0
  local RxStatus  = STR_DATA_U8(4)   -- FlightMode   (Hex:  MS)  M=Flight Mode, S=Status (0=init, 2=Ready, 3=Sensor Fault)
  
  -- GAINS
  local GRoll   = STR_DATA_U8(5)
  local GPitch  = STR_DATA_U8(6)
  local GYaw    = STR_DATA_U8(7)

  -- Attitude (int16)
  local ARoll   = STR_DATA_I16(8)
  local APitch  = STR_DATA_I16(10)
  local AYaw    = STR_DATA_I16(12)

  local ATTR_NUM = TEXT_SIZE + RIGHT

  lcd.drawText (1,0, "BLADE Alpha6 Monitor", TEXT_SIZE+INVERS)

  local y = Y_DATA
  local x_data1 = X_COL1_DATA+X_DATA_LEN
  local x_data2 = X_COL1_DATA+X_DATA_LEN*2
  local x_data3 = X_COL1_DATA+X_DATA_LEN*3

  -- Flight Mode
  lcd.drawText (1,y, "F-Mode:"..parseAlpha6FM(RxStatus), TEXT_SIZE)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (x_data1,y, "Attitude", ATTR_NUM + BOLD)
  lcd.drawText (x_data2,y, "Gyro", ATTR_NUM + BOLD)
  lcd.drawText (x_data3,y, "Gain", ATTR_NUM + BOLD)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER,y, "Rol:", TEXT_SIZE)
  lcd.drawText (x_data1,y, STR_DispFloat1(ARoll,"o"), ATTR_NUM)
  lcd.drawText (x_data2,y, "-", ATTR_NUM)
  lcd.drawText (x_data3,y, STR_Disp(GRoll), ATTR_NUM)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER,y, "Pitch:", TEXT_SIZE)
  lcd.drawText (x_data1,y, STR_DispFloat1(APitch,"o"), ATTR_NUM)
  lcd.drawText (x_data2,y, "-", ATTR_NUM)
  lcd.drawText (x_data3,y, STR_Disp(GPitch), ATTR_NUM)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER,y, "Yaw:", TEXT_SIZE)
  lcd.drawText (x_data1,y, STR_DispFloat1(AYaw,"o"), ATTR_NUM)
  lcd.drawText (x_data2,y, "-", ATTR_NUM)
  lcd.drawText (x_data3,y, STR_Disp(GYaw), ATTR_NUM)

  y = y + Y_LINE_HEIGHT + Y_LINE_HEIGHT
  lcd.drawText (0,y, string.format("Bat: %0.2f V",bat), TEXT_SIZE)
end

-----------------------------------------------------------------------------------

local function drawAS3XMonitor()
  if event == EVT_VIRTUAL_EXIT then -- Exit?? Clear menu data
    STR_close()
    return
  end

  -- Proces Telementry message
  STR_isDataReady(I2C_LEGACY_AS3X) -- Specktrum Telemetry ID of data receive

  -- GAINS
  local GRoll  = STR_DATA_U8(2)
  local GPitch = STR_DATA_U8(3)
  local GYaw   = STR_DATA_U8(4)

  -- HEADING
  local HRoll  = STR_DATA_U8(5)
  local HPitch = STR_DATA_U8(6)
  local HYaw   = STR_DATA_U8(7)

  -- ACTIVE
  local ARoll  = STR_DATA_U8(8)
  local APitch = STR_DATA_U8(9)
  local AYaw   = STR_DATA_U8(10)

  local FM    =  STR_DATA_U8(11)

  -- bit 7 1 --> FM present in bits 0,1 except 0xFF --> not present
  if (FM~=nil and bit32.band(FM,0x80)==0x80) then  
    FM = bits32.band(FM,0x03)
  end

  lcd.clear()
  lcd.drawText (1,0, "Plane AR636 AS3X Legacy Gains", TEXT_SIZE+INVERS)

  local y = Y_DATA
  local x_data1 = X_COL1_DATA+X_DATA_LEN
  local x_data2 = X_COL1_DATA+X_DATA_LEN*2
  local x_data3 = X_COL1_DATA+X_DATA_LEN*3.1

  local ATTR_NUM = TEXT_SIZE + RIGHT

  -- Flight Mode
  lcd.drawText (1,y, "F-Mode:   "..STR_Disp(FM), TEXT_SIZE)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (x_data1,y, "Rate", ATTR_NUM + BOLD)
  lcd.drawText (x_data2,y, "Head", ATTR_NUM + BOLD)
  lcd.drawText (x_data3+X_DATA_SPACE*3,y, "Actual", ATTR_NUM + BOLD)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER+X_DATA_LEN,y, "Roll %:", ATTR_NUM)
  lcd.drawText (x_data1,y, STR_Disp(GRoll), ATTR_NUM)
  lcd.drawText (x_data2,y, STR_Disp(HRoll), ATTR_NUM)
  lcd.drawText (x_data3,y, STR_Disp(ARoll), ATTR_NUM)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER+X_DATA_LEN,y, "Pitch %:", ATTR_NUM)
  lcd.drawText (x_data1,y, STR_Disp(GPitch), ATTR_NUM)
  lcd.drawText (x_data2,y, STR_Disp(HPitch), ATTR_NUM)
  lcd.drawText (x_data3,y, STR_Disp(APitch), ATTR_NUM)

  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL1_HEADER+X_DATA_LEN,y, "Yaw %:", ATTR_NUM)
  lcd.drawText (x_data1,y, STR_Disp(GYaw), ATTR_NUM)
  lcd.drawText (x_data2,y, STR_Disp(HYaw), ATTR_NUM)
  lcd.drawText (x_data3,y, STR_Disp(AYaw), ATTR_NUM)
end

-----------------------------------------------------------------------------------
local TG_LineText = {nil}
local function drawTextGen(event)
  if event == EVT_VIRTUAL_EXIT then -- Exit?? Clear menu data
    STR_close()
    TG_LineText = {nil}
    return
  end

  -- Proces TEXT GEN Telementry message
  if STR_isDataReady(I2C_TEXT_GEN) then -- Specktrum Telemetry ID of data received
    local instanceNo = STR_data[1]
    
    -- LineNo: 0 = title, 1-8 for general, 254 = Refresh backlight, 255 = Erase all text on screen
    local lineNo = STR_data[2]

    if (lineNo==254) then
      -- Backlight??
    elseif (lineNo==255) then 
        TG_LineText = {nil}
    else 
      local line = ""
      for i=0,13 do
        line = line .. string.char(STR_data[ 3 + i ])
      end
      TG_LineText[lineNo]=line
    end
  end

  lcd.clear()
  if (TG_LineText[0]) then   -- Header
    lcd.drawText (X_COL1_HEADER,0,  "TextGen: "..TG_LineText[0].."   ", TEXT_SIZE + BOLD + INVERS)
  else
    lcd.drawText (X_COL1_HEADER,0, "TextGen", TEXT_SIZE + INVERS)
  end

  -- Menu lines
  local y = Y_DATA
  for i=1,8 do
    if (TG_LineText[i]) then
      lcd.drawText (X_COL1_HEADER,y,  TG_LineText[i], TEXT_SIZE)
    end
    y = y + Y_LINE_HEIGHT
  end
end

-----------------------------------------------------------------------------------

local QOS_Title  = {[0]="A:", "B:", "L:", "R:", "F:", "H:"}
local QOS_Value  = {[0]="--","--","--","--","--","--","--"}

local function drawFlightLogScreen(event)
  local H = 0
    
  if  STR_isDataReady(I2C_QOS) then
    QOS_Value[0] = STR_Disp(STR_DATA_U16(2)) -- A
    QOS_Value[1] = STR_Disp(STR_DATA_U16(4)) -- B
    QOS_Value[2] = STR_Disp(STR_DATA_U16(6)) -- L
    QOS_Value[3] = STR_Disp(STR_DATA_U16(8)) -- R 
    QOS_Value[4] = STR_Disp(STR_DATA_U16(10)) -- F
    H = STR_DATA_U16(12) or 0 -- H
    QOS_Value[5] =  STR_Disp(H)
    QOS_Value[6] = STR_DispFloat2(STR_DATA_U16(14)) 
  end

-- draw labels and params on screen
  local ATTR_NUM =  TEXT_SIZE + RIGHT
  
  lcd.clear()
  lcd.drawText (X_COL1_HEADER, Y_HEADER, "Flight Log", TEXT_SIZE + INVERS)

  local activeParam = H - 1 -- H 

  local y = Y_LINE_HEIGHT+Y_DATA

  for iParam=0,3 do   -- A,B,L,R 
    -- highlight selected parameter  (rund)
    local attr = ((activeParam % 4)==iParam) and INVERS or 0

    lcd.drawText (X_COL1_HEADER, y, QOS_Title[iParam], TEXT_SIZE)
    
    -- Values
    local val = QOS_Value[iParam] 
    if (val~=0x4000) then  -- Active value  (this will blink)
        lcd.drawText (X_COL1_DATA + X_DATA_LEN, y, val, attr + ATTR_NUM)
    end

    y = y + Y_LINE_HEIGHT
  end

  y = Y_LINE_HEIGHT+Y_DATA
  for iParam=4,5 do  -- F, H
    lcd.drawText (X_COL2_HEADER, y, QOS_Title[iParam], TEXT_SIZE_BIG )
    lcd.drawText (X_COL2_DATA + X_DATA_LEN, y, QOS_Value[iParam], TEXT_SIZE_BIG + RIGHT )
    y = y + Y_LINE_HEIGHT*2
  end

  -- Bat 
  y = y + Y_LINE_HEIGHT
  lcd.drawText (X_COL2_HEADER, y, "Bat:", TEXT_SIZE)
  lcd.drawText (X_COL2_DATA + X_DATA_LEN, y, QOS_Value[6], ATTR_NUM)
  lcd.drawText (X_COL2_DATA + X_DATA_LEN + X_DATA_SPACE, y, " v", TEXT_SIZE)
end

-----------------------------------------------------------------------------------

local telPage = 1
local telPageSelected = 0
local pageTitle = {[0]="Main", "Flight Log", "Blade Version", "BladeAdjust", "Blade Alpha6 Monitor",
                        "Plane AS3X Monitor", "TextGen", }

local function drawMainScreen(event) 
  lcd.clear()
  lcd.drawText (X_COL1_HEADER, Y_HEADER, "Main Tel (AR636) v1.1", TEXT_SIZE + INVERS)

  for iParam=1,#pageTitle do    
    -- highlight selected parameter
    local attr = (telPage==iParam) and INVERS or 0

    -- set y draw coord
    local y = (iParam-1)*Y_LINE_HEIGHT+Y_DATA 
    
    -- labels
    local x = X_COL1_HEADER
    local val = pageTitle[iParam]
    lcd.drawText (x, y, val, attr + TEXT_SIZE)
  end

  if event == EVT_VIRTUAL_PREV then
    if (telPage>1) then telPage = telPage - 1 end
  elseif event == EVT_VIRTUAL_NEXT then
    if (telPage<#pageTitle) then telPage = telPage + 1 end
  elseif event == EVT_VIRTUAL_ENTER then
    telPageSelected = telPage
  end
end


local pageDraw  = {[0]=drawMainScreen, drawFlightLogScreen, drawVersionScreen, bladeAdjustScreen, 
                       drawAlpha6Monitor, drawAS3XMonitor, drawTextGen, }

local function run_func(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  -- draw specific page 
  pageDraw[telPageSelected](event)

  if event == EVT_VIRTUAL_EXIT then
    if (telPageSelected==0) then return 1 end  -- on Main?? Exit Script 
    telPageSelected = 0  -- any page, return to Main 
  end

  return 0
end

local function init_func()
  
  if (LCD_W <= 128 or LCD_H <=64) then -- Smaller Screens 
    TEXT_SIZE = SMLSIZE 
    TEXT_SIZE_BIG         = DBLSIZE

    X_COL1_HEADER         = 1
    X_COL1_DATA           = 20

    X_COL2_HEADER         = 60
    X_COL2_DATA           = 90

    X_DATA_LEN            = 28 
    X_DATA_SPACE          = 1


    Y_LINE_HEIGHT         = 8
    Y_DATA                = Y_HEADER + Y_LINE_HEIGHT

  end
end

return { run=run_func,  init=init_func  }
