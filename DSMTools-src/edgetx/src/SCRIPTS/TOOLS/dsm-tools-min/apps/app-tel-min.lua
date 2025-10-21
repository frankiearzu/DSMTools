local toolName = "TNS|DSMTools Min 2.2|TNE"
local version  = "2.2"
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

local SIMULATION            = false

local TEXT_SIZE             = 0 -- NORMAL
local TEXT_SIZE_BIG         = MIDSIZE
local LCD_COL1_HEADER       = 6
local LCD_COL1_DATA         = 60
local LCD_COL2_HEADER       = 170
local LCD_COL2_DATA         = 220
local LCD_LINE_HEIGHT       = 20
local LCD_ROW_HEADER        = 0
local LCD_ROW_DATA          = LCD_ROW_HEADER + LCD_LINE_HEIGHT*2 
local LCD_DATA_LEN          = 80 
local LCD_DATA_SPACE        = 5

local C_UP                  = CHAR_UP
local C_DOWN                = CHAR_DOWN

local MENU_MAX_PER_PAGE     = 7

local U8_NODATA             = 0xFF
local U16_NODATA            = 0xFFFF
local U32_NODATA            = 0xFFFFFFFF
local I8_NODATA             = 0x7F
local I16_NODATA            = 0x7FFF
local I32_NODATA            = 0x7FFFFFFF

local FrameData             = {[0]=0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF, 0xFF, 0x0FF}

local I2C_FLITECTRL         = 0x05
local I2C_TEXT_GEN          = 0x0C
local I2C_GPS_STATS         = 0x17
local I2C_GPS_LOC           = 0x16
local I2C_ESC               = 0x20
local I2C_GPS_BIN           = 0x26
local I2C_REMOTE_ID         = 0x27
local I2C_FP_BATT           = 0x34
local I2C_SMART_BAT         = 0x42
local I2C_QOS               = 0x7F


local MainScreen = {
  ItemHighlight   = 2,
  ItemSelected    = 1,
  Offset          = 0
}

local DefaultProcessor   = {}

local FlightLog = {
    QOS_Title  = {[0]="A:", "B:", "L:", "R:", "F:", "H:"},
    QOS_Value  = {[0]=nil,nil,nil,nil,nil,nil,nil}
}


local TextGen   = {
  TG_Lines = {[0]=nil}
}

local AS3XSettings = {
  AS3X_Flags = nil,
  AS3X_State = nil,
  AS3X_FlagsMsg="",
  AS3X_FmMsg="--",

  AS3X_Data = {[0]=nil,nil,nil,nil,nil,nil,
                   nil,nil,nil,nil,nil,nil,
                   nil,nil,nil,nil,nil,nil}
}

local SmartESC = {
  ESC_Title= {[0]="","RPM:","Volts:","Motor:","Mot Out:","Throttle:","FET Temp:", "BEC V:", "BEC T:", "BEC A:"},
  ESC_uom  = {[0]="",""," V"," A"," %"," %"," C", " V"," C"," A"},
  ESC_Value= {[0]=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
  ESC_Min  = {[0]=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
  ESC_Max  = {[0]=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
}

local SmartBat = {
  BAT_Title   ={[0]="","Bat:","Curr:", "Temp:", "Used:", "Rem :", "RX:"},
  BAT_uom     ={[0]="","V","mA","C","mAh","%","V"},
  BAT_Values  ={[0]=nil,nil,nil,nil,nil,nil,nil},
  BAT_Cells   ={[0]=0,0,0,0,0,0,0,0,0,0,0,0}
}

local FlightPack = {
  FP_Title= {[0]="Curr:","Used:","Temp:"},
  FP_uom  = {[0]=" A"," mAh"," C"},
  FP_Value= {[0]=nil,nil,nil,nil,nil,nil}
}

local Gps = {
  GPS_Step = 0,
  GPS_Lat = 0,
  GPS_Lat_Str = "",
  GPS_Lon = 0,
  GPS_Lon_Str = "",
  GPS_AltHigh = 0,
  GPS_Alt = 0,
  GPS_Course = 0,
  GPS_Speed = 0,
  GPS_Sats = 0,
  GPS_Time_UTC = ""
}

local GpsBin = { }
local SkyGps = {}

local SkyRemoteId = {
  RID_OwnerInfo = "",
  RID_UAS_ID = "",
  RID_Status = 0,
  
  OID_L00="",
  OID_L20="",
  OID_L40="",
  
  UAS_L60="",
  UAS_L80="",
  
  DEV_LA0_S="",
  DEV_LA0_H="",
  DEV_MODEL=""
}


MainScreen.menu = {
  --   Title,            Processor,         param
    {"Main Menu ",        MainScreen,       nil}, 
    {"Flight Log",        FlightLog,        nil},
    {"TextGen",           TextGen,          nil},
    {"AS3X Settings",     AS3XSettings,     1},
    {"SAFE Limits",       AS3XSettings,     2},
    {"ESC Status",        SmartESC,         nil},
    {"Smart BAT",         SmartBat,         nil},
    {"Flight Pack",       FlightPack,       nil},
    {"GPS",               Gps,              nil},
    {"GPS (Binary)",      GpsBin,           nil},
    {"GPS (SkyID)",       SkyGps,           nil},
    {"RemoteID/SkyID)",   SkyRemoteId,      nil},

}

-----------------------------------------------------------------------------------

local function openTelemetryRaw(i2cId)
  --Init telemetry  (Spectrun Telemetry Raw STR)
  for i=0,15 do
    FrameData[i] = U8_NODATA
  end

  multiBuffer( 0, string.byte('S') )
  multiBuffer( 1, string.byte('T') )
  multiBuffer( 2, string.byte('R') ) 
  multiBuffer( 3, i2cId ) -- Monitor this teemetry data
  multiBuffer( 4, 0 ) -- Allow to get Data
end

local function closeTelemetryRaw()
  multiBuffer(0, 0) -- Destroy the STR header 
  multiBuffer(3, 0) -- Not requesting any Telementry ID
end

local function getFrameData(i2cId) 
  if (multiBuffer(0)~=string.byte('S') or multiBuffer(3) ~= i2cId ) then -- First time run???
    openTelemetryRaw(i2cId) -- I2C_ID 
  end

  if multiBuffer( 4 ) == i2cId then
    for i=0,15 do
      FrameData[0+i] = multiBuffer(4+i)
    end
    multiBuffer( 4, 0 ) -- Allow to get Data
    return true
  end
  return false
end

-----------------------------------------------------------------------------------
local function Unsigned_to_SInt16(value) 
  if value >= 0x8000 then  -- Negative value??
      return value - 0x10000
  end
  return value
end

local function getI8(p)
  local val = FrameData[p]
  if (val == I8_NODATA) then return nil else return val end
end

local function getU8(p)
  local val = FrameData[p]
  if (val == U8_NODATA) then return nil else return val end
end

local function getI16LE(p)
     local val = FrameData[p] + bit32.lshift(FrameData[p+1], 8)
     if (val == I16_NODATA) then return nil else return Unsigned_to_SInt16(val) end
end

local function getU16LE(p)
  local val = FrameData[p] + bit32.lshift(FrameData[p+1], 8)
  if (val == U16_NODATA) then return nil else return val end
end

local function getU16(p)
  local val = bit32.lshift(FrameData[p], 8) + FrameData[p+1]
  if (val == U16_NODATA) then return nil else return val end
end

local function getI16(p)
  local val = bit32.lshift(FrameData[p], 8) + FrameData[p+1]
  if (val == I16_NODATA) then return nil else return val end
end

local function getI32(p)
  local val = bit32.lshift(FrameData[p], 24) + bit32.lshift(FrameData[p+1], 16) + 
              bit32.lshift(FrameData[p+2], 8)  + FrameData[p+3]
  local mask = 0x80000000
  val = bit32.bxor(val, mask) - mask
  if (val == I32_NODATA) then return nil else return val end
end

local function getU32LE(p)
  local val = bit32.lshift(FrameData[p+3], 24) + bit32.lshift(FrameData[p+2], 16) + 
              bit32.lshift(FrameData[p+1], 8)  + FrameData[p]
  if (val == U32_NODATA) then return nil else return val end
end

local function getString(p,len,breakOnZero)
  local line=""
  for i=0,len-1 do
    local ch = FrameData[ p + i ]
    if (ch==0 and breakOnZero) then break; end
    if (ch<32 or ch > 126) then line=line.."."
    else 
      line = line .. string.char(ch)
    end
  end
  return line
end

local function getHexString(p,len)
  local line=""
  for i=0,len-1 do
    local ch = FrameData[ p + i ]
    line = line .. string.format("%02X",ch).." "
  end
  return line
end

local function getBCD(p)
  local ch = FrameData[p]
  local d1 = bit32.band(bit32.rshift(ch, 4), 0x0F)
  local d2 = bit32.band(ch, 0x0F)

  return d1*10 + d2
end

local function formatNilValue(val, postfix)
  if (val == nil) then return "---" end
  return val .. (postfix or "")
end

local function formatFloat1(val,postfix)
  if (val == nil) then return "---" end
  return string.format("%0.1f",val/10) .. (postfix or "")
end


local function formatWithComma(formatted)
  if (formatted==nil) then return nil end
  local k=1
  while k ~= 0 do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)","%1,%2")
  end
  return formatted
end

-----------------------------------------------------------------------------------

function DefaultProcessor.event(key)
  if key == EVT_VIRTUAL_EXIT then
      closeTelemetryRaw()
      MainScreen.ItemSelected = 1 -- Main Menu
  end
end

-----------------------------------------------------------------------------------

function FlightLog.wakeup()
  local this = FlightLog

  if (SIMULATION) then
    FrameData   = {[0]=0x7F,0x00,0x00,0x5A,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x02,0x02}
  end

  if  getFrameData(I2C_QOS) then
    this.QOS_Value[0] = getU16(2) -- A
    this.QOS_Value[1] = getU16(4) -- B
    this.QOS_Value[2] = getU16(6) -- L
    this.QOS_Value[3] = getU16(8) -- R 
    this.QOS_Value[4] = getU16(10) -- F
    
    local holds = getU16(12)   -- H
    if (holds == I16_NODATA) then holds = nil end
    this.QOS_Value[5] = holds

    this.QOS_Value[6] = getU16(14)
  end
end

function FlightLog.paint()  
  -- draw labels and params on screen
  local this = FlightLog
  
  lcd.clear()
  lcd.drawText (LCD_COL1_HEADER, LCD_ROW_HEADER, "Flight Log", TEXT_SIZE + INVERS)

  local activeParam = (this.QOS_Value[5] or 0) - 1 -- H 

  local y = LCD_LINE_HEIGHT+LCD_ROW_DATA

  for iParam=0,3 do   -- A,B,L,R 
    -- highlight selected parameter  (rund)
    local attr = ((activeParam % 4)==iParam) and INVERS or 0

    lcd.drawText (LCD_COL1_HEADER, y, this.QOS_Title[iParam], TEXT_SIZE)
    
    -- Values
    local val = this.QOS_Value[iParam] 
    if (val==0x4000) then  -- Active value
        lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, "  ", attr + TEXT_SIZE + RIGHT + INVERS)
    else
        lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, formatNilValue(val), attr + TEXT_SIZE + RIGHT)
    end

    y = y + LCD_LINE_HEIGHT
  end

  y = LCD_LINE_HEIGHT+LCD_ROW_DATA
  for iParam=4,5 do  -- F, H
    lcd.drawText (LCD_COL2_HEADER, y, this.QOS_Title[iParam], TEXT_SIZE_BIG)
    lcd.drawText (LCD_COL2_DATA + LCD_DATA_LEN, y, formatNilValue(this.QOS_Value[iParam]), TEXT_SIZE_BIG + RIGHT)
    y = y + LCD_LINE_HEIGHT*2
  end

  -- Bat 
  local bat = this.QOS_Value[6]
  if (bat ~= nil) then bat = string.format("%0.2f", bat/100) else bat = "--" end
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL2_HEADER, y, "Bat:", TEXT_SIZE)
  lcd.drawText (LCD_COL2_DATA + LCD_DATA_LEN, y, bat, TEXT_SIZE + RIGHT)
  lcd.drawText (LCD_COL2_DATA + LCD_DATA_LEN + LCD_DATA_SPACE, y, " v", TEXT_SIZE)
end

FlightLog.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function AS3XSettings.paint(page)
  local this =  AS3XSettings
  
  lcd.clear()
  if (page==1) then
    lcd.drawText (1,0, "AS3X Settings", TEXT_SIZE + INVERS)
  else
    lcd.drawText (1,0, "SAFE Limits", TEXT_SIZE + INVERS)
  end

  local y = LCD_ROW_DATA
  -- Flight Mode
  lcd.drawText (LCD_COL1_HEADER,y, "FM: "..this.AS3X_FmMsg, TEXT_SIZE)
  lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN*0.4,y, "Flags: "..formatNilValue(this.AS3X_Flags), TEXT_SIZE)
  lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN*0.7,y, "State: "..formatNilValue(this.AS3X_State), TEXT_SIZE)

  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER,y, this.AS3X_FlagsMsg, TEXT_SIZE)

  y = y + LCD_LINE_HEIGHT

  if (fm == 0xE) then
    return
  end

  if (page==1) then
    lcd.drawText (LCD_COL1_HEADER+LCD_DATA_LEN*0.3,y, "AS3X Gains", TEXT_SIZE+BOLD)
    lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN*0.3,y, "AS3X Headings", TEXT_SIZE+BOLD)
    
    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Roll:", TEXT_SIZE)
    lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[0]), TEXT_SIZE + RIGHT) -- Roll G 
    lcd.drawText (LCD_COL2_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[3]), TEXT_SIZE + RIGHT) -- Roll H 

    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Pitch:", TEXT_SIZE)
    lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[1]), TEXT_SIZE + RIGHT)  -- Pitch G
    lcd.drawText (LCD_COL2_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[4]), TEXT_SIZE + RIGHT) -- Pitch H 

    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Yaw:", TEXT_SIZE)
    lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[2]), TEXT_SIZE + RIGHT) -- Yaw G
    lcd.drawText (LCD_COL2_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[5]), TEXT_SIZE + RIGHT) -- Yaw H
  end


  if (page==2) then
    local x_data1 = LCD_COL1_DATA+LCD_DATA_LEN
    local x_data2 = LCD_COL2_HEADER+LCD_DATA_LEN*1.6

    lcd.drawText (LCD_COL1_HEADER+LCD_DATA_LEN*0.3,y, "SAFE Gains", TEXT_SIZE+BOLD)
    lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN*0.1,y, "Angle Limits", TEXT_SIZE+BOLD)
  
    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Roll:", TEXT_SIZE)
    lcd.drawText (x_data1,y, formatNilValue(this.AS3X_Data[6]), TEXT_SIZE + RIGHT)

    lcd.drawText (LCD_COL2_HEADER,y, "Roll R:", TEXT_SIZE)
    lcd.drawText (x_data2,y, formatNilValue(this.AS3X_Data[12]), TEXT_SIZE + RIGHT)


    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Pitch:", TEXT_SIZE)
    lcd.drawText (x_data1,y,formatNilValue(this.AS3X_Data[7]), TEXT_SIZE + RIGHT)

    lcd.drawText (LCD_COL2_HEADER,y, "Roll L:", TEXT_SIZE)
    lcd.drawText (x_data2,y,formatNilValue(this.AS3X_Data[13]), TEXT_SIZE + RIGHT)


    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Yaw:", TEXT_SIZE)
    lcd.drawText (x_data1,y, formatNilValue(this.AS3X_Data[8]), TEXT_SIZE + RIGHT)

    lcd.drawText (LCD_COL2_HEADER,y, "Pitch U:", TEXT_SIZE)
    lcd.drawText (x_data2,y, formatNilValue(this.AS3X_Data[14]), TEXT_SIZE + RIGHT)

    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL2_HEADER,y, "Pitch D:", TEXT_SIZE)
    lcd.drawText (x_data2,y, formatNilValue(this.AS3X_Data[15]), TEXT_SIZE + RIGHT)
  end
end

function AS3XSettings.wakeup()
  local this =  AS3XSettings

  if  getFrameData(I2C_FLITECTRL) then
    this.AS3X_FlagsMsg=""

    this.AS3X_Flags = getU8(2)
    this.AS3X_State = getU8(3)

    local fm = bit32.band(FrameData[4],0xF)
    local axis = bit32.band(FrameData[5],0xF)  -- 0=Gains,1=Headings,2=Angle Limits (cointinus iterating to provide all values)
  
    if (fm ~= 0x0E) then
      local separator=""
      
      this.AS3X_FmMsg = ""..(fm+1)
      -- flags bits:  Safe Envelop, ?, Angle Demand, Stab 
      if (bit32.band(this.AS3X_Flags,0x1)~=0) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg.."AS3X Stab"; separator=", " end
      -- This one, only one should show
      if (bit32.band(this.AS3X_Flags,0x2)~=0) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg..separator.."Safe Level" 
      elseif (bit32.band(this.AS3X_Flags,0x8)~=0) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg..separator.."Safe Envelope" 
      elseif (bit32.band(this.AS3X_Flags,0x4)~=0) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg..separator.."Heading" end
  
      --axis: 0=Gains+Headings (RG,PG,YG,RH,PH,YH), 1=Safe Gains (R,P,Y),2=Angle Limits(L,R,U,D) 
      --Constantly changing from 0..2 to represent different data, thats why we have to store the values
      --in a script/global variable, and not local to the function
      local s = axis*6
      for i=0,5 do 
        this.AS3X_Data[s+i] = getU8(6+i)
      end
    else
      -- FM==0xE
      if (this.AS3X_State==0) then this.AS3X_FlagsMsg="Initializing.."; this.AS3X_FmMsg="--"
      elseif (this.AS3X_State==2) then this.AS3X_FlagsMsg="Error: FM-Switch-Range" end
    end  
  end
end

AS3XSettings.event = DefaultProcessor.event

-----------------------------------------------------------------------------------
function SmartESC.paint()
  local this = SmartESC

  lcd.clear() 
  lcd.drawText (1,0, "ESC", TEXT_SIZE+INVERS)

  local y = 0
  local x_data = LCD_COL1_DATA+LCD_DATA_LEN*1.5
  local x_data2 = LCD_COL2_DATA+LCD_DATA_LEN*0.5
  local x_data3 = x_data2 + LCD_DATA_LEN*0.8

  local fontD = TEXT_SIZE + RIGHT
  local fontH1 = TEXT_SIZE + BOLD + RIGHT

  lcd.drawText (x_data,y , "Status", fontH1)
  lcd.drawText (x_data2,y, "Min", fontH1)
  lcd.drawText (x_data3,y, "Max", fontH1)
  
  y = LCD_ROW_DATA
  for i=1,9 do
      lcd.drawText (LCD_COL1_HEADER,y, this.ESC_Title[i], TEXT_SIZE)

      local val = this.ESC_Value[i]
      local min = this.ESC_Min[i]
      local max = this.ESC_Max[i]
      if (i==1) then -- RPM
        val = formatWithComma(val)
        min = formatWithComma(min)
        max = formatWithComma(max)
      end
      lcd.drawText (x_data,y, formatNilValue(val), fontD)
      lcd.drawText (x_data,y, this.ESC_uom[i], TEXT_SIZE)
      lcd.drawText (x_data2,y, formatNilValue(min), fontD)
      lcd.drawText (x_data3,y, formatNilValue(max), fontD)
      y = y + LCD_LINE_HEIGHT
  end
end

function SmartESC.wakeup()
  local this = SmartESC

  local function setDataMinMax(p,val,format)
    if (val==nil) then return end;

    this.ESC_Value[p]=val
    if (this.ESC_Min[p]==nil) then this.ESC_Min[p]=val else this.ESC_Min[p] = math.min(this.ESC_Min[p],val) end
    if (this.ESC_Max[p]==nil) then this.ESC_Max[p]=val else this.ESC_Max[p] = math.max(this.ESC_Max[p],val) end
  end

  if  getFrameData(I2C_ESC) then
      -- Big Endian
      local rpm   = getU16(2)  -- RPM * 10
      local volts = getU16(4)  -- Volts / 100
      local temp  = getU16(6)  -- Temp FET / 10
      local curr  = getU16(8)  -- Curr / 100
      local tempB = getU16(10)  -- Temp BEC / 10 
      local currB = getU8(12) -- Curr BEC / 10
      local voltsB= getU8(13) -- Volts BEC / 20
      local outP  = getU8(14) -- % Output / 2
      local thrP  = getU8(15) -- Throttle %  / 2

      if (rpm) then setDataMinMax(1,rpm*10) end -- RPM
      if (volts) then setDataMinMax(2,volts/100,"%0.2f") end -- Volts
      if (curr) then setDataMinMax(3,curr/100,"%0.2f") end -- Curr
      if (outP) then setDataMinMax(4,outP/2) end -- Output
      if (thrP) then setDataMinMax(5,thrP/2) end -- Throttle
      if (temp) then setDataMinMax(6,temp/10) end -- Temp FET
      if (voltsB) then setDataMinMax(7,voltsB/20,"%0.2f") end -- Volts BEC
      if (tempB) then setDataMinMax(8,tempB/10) end -- Temp BEC
      if (currB) then setDataMinMax(9,currB/10) end -- Cur BEC
  end
end

SmartESC.event = DefaultProcessor.event

-----------------------------------------------------------------------------------
function SmartBat.paint()
  local this = SmartBat

  lcd.clear()
  lcd.drawText (1,0, "Battery Stats", TEXT_SIZE+INVERS)
  
  local y = LCD_ROW_DATA
  local x_data = LCD_COL1_DATA+LCD_DATA_LEN+LCD_DATA_SPACE*3
  for i=1,6 do
      lcd.drawText (LCD_COL1_HEADER, y, this.BAT_Title[i], TEXT_SIZE + BOLD)
      lcd.drawText (x_data, y, formatNilValue(this.BAT_Values[i]), TEXT_SIZE + RIGHT)
      lcd.drawText (x_data+LCD_DATA_SPACE, y, this.BAT_uom[i], TEXT_SIZE)
      y = y + LCD_LINE_HEIGHT
  end

  y = LCD_ROW_DATA
  x_data = LCD_COL2_DATA+LCD_DATA_LEN+LCD_DATA_SPACE*5
  for i=0,8 do
      if ((this.BAT_Cells[i] or 0) > 0) then
        lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN/2,y, "Cel "..(i+1)..":", TEXT_SIZE + BOLD)
        lcd.drawText (x_data,y, string.format("%2.2f",this.BAT_Cells[i]), TEXT_SIZE + RIGHT)
        lcd.drawText (x_data+LCD_DATA_SPACE,y, "V", TEXT_SIZE)
      end
      y = y + LCD_LINE_HEIGHT
  end
end

function SmartBat.wakeup()
  local this = SmartBat

  local function getVTotal()
    local VTotal=0
    for i=0,11 do
        VTotal = VTotal + this.BAT_Cells[i]
    end
    return VTotal
  end

  if  getFrameData(I2C_SMART_BAT) then
    -- Big Endian
    local chType = FrameData[2]
    local msgType = bit32.band(chType,0xF0)
  
    if (msgType==0x00) then -- Battery Real Time
      local temp   = getI8(3)   -- Temp C
      local curr   = getU32LE(4)  -- Curr (mA)
      local usage  = getU16LE(8)  -- Usage (mAh)
      local minCell= getU16LE(10) -- MinCell (mV)
      local maxCell= getU16LE(12) -- MaxCell (mV)

      this.BAT_Values[2] = formatWithComma(curr)
      this.BAT_Values[3] = temp 
      this.BAT_Values[4] = formatWithComma(usage)
      this.BAT_Values[5] = nil

      local RX_Volts = getValue("A2") -- RX
      if (RX_Volts) then 
        this.BAT_Values[6] = string.format("%0.2f",RX_Volts)
      end
    elseif (msgType==0x10) then -- Cell 1-6
      local temp   = getI8(3)   -- Temp C
      for i=0,5 do
        this.BAT_Cells[i] = (getU16LE(4+i*2) or 0) / 1000   -- Usage (mV)
      end
      this.BAT_Values[3] = temp
    elseif (msgType==0x20) then -- Cell 7-12
      local temp   = getI8(3)   -- Temp C
      for i=0,5 do
        this.BAT_Cells[6+i] = (getU16LE(4+i*2) or 0) / 1000 -- Usage (mV)
      end
      this.BAT_Values[3] = temp
    end

    local vTotal = getVTotal()
  
    --if (vTotal==0) then -- No Inteligent Battery,use intelligent ESC if any
    --  local ESC_Volts = getValue("EVIN") or 0 -- Volts
    --  local ESC_Current = getValue("ECUR") or 0 -- Current
    --
    --  vTotal = ESC_Volts
    --  BAT_Values[2] = string.format("%d",ESC_Current * 1000)
    --end

    this.BAT_Values[1] = string.format("%0.2f",vTotal)
  end
end

SmartBat.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function TextGen.paint()
  local this = TextGen

  lcd.clear()
  local y = LCD_ROW_DATA
  local x = LCD_COL1_HEADER
  local hAttr = TEXT_SIZE + INVERS + BOLD

  if (LCD_H <= 64) then 
    -- Need to be able to show 8 lines of data + heather
    -- show header on the right hand side to gain 1 line
    x = 128
    y = 0
    hAttr = hAttr + RIGHT
  else
    y = LCD_ROW_DATA + LCD_LINE_HEIGHT
  end

  lcd.drawText (x,0, "TextGen", hAttr)
  if (this.TG_Lines[0]) then   -- Header
    lcd.drawText (x,LCD_LINE_HEIGHT, this.TG_Lines[0], hAttr)
  end

  -- Menu lines
  
  for i=1,8 do
    if (this.TG_Lines[i]) then
      lcd.drawText (LCD_COL1_HEADER,y,  this.TG_Lines[i], TEXT_SIZE)
    end
    y = y + LCD_LINE_HEIGHT
  end
end

function TextGen.wakeup()
  local this = TextGen

  -- Proces TEXT GEN Telementry message
  if getFrameData(I2C_TEXT_GEN) then -- Specktrum Telemetry ID of data received
    local instanceNo = FrameData[1]
    
    -- LineNo: 0 = title, 1-8 for general, 254 = Refresh backlight, 255 = Erase all text on screen
    local lineNo = FrameData[2]

    if (lineNo==254) then
      -- Backlight??
    elseif (lineNo==255) then 
        this.TG_Lines = {nil}
    else 
      local line = ""
      for i=0,12 do
        line = line .. string.char(FrameData[ 3 + i ])
      end
      this.TG_Lines[lineNo]=line
    end
  end
end


function TextGen.event(key)
  if key == EVT_VIRTUAL_EXIT then -- Exit?? Clear menu data
    closeTelemetryRaw()
    DefaultProcessor.event(key)
  end
end

-----------------------------------------------------------------------------------

function FlightPack.paint()
  local this = FlightPack
  -- draw labels and params on screen
  local y = LCD_ROW_HEADER
  local attrH2= TEXT_SIZE + RIGHT + INVERS
  local attrD = TEXT_SIZE + RIGHT

  lcd.clear()
  lcd.drawText (LCD_COL1_HEADER, y, "Flight Pack", TEXT_SIZE + INVERS)

  y = y + LCD_LINE_HEIGHT + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN, y, "Batt 1", attrH2)
  lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN, y, "Batt 2", attrH2)

  y = y + LCD_LINE_HEIGHT


  for i=0,2 do
    lcd.drawText (LCD_COL1_HEADER, y, this.FP_Title[i], TEXT_SIZE)

    local disp1,disp2
    if (i==1) then
      -- Curr Used mAh (integer)
      disp1 = formatNilValue(this.FP_Value[i])
      disp2 = formatNilValue(this.FP_Value[i+3])
    else
      -- Instant Amp / Temp (Float)
      disp1 = formatFloat1(this.FP_Value[i])
      disp2 = formatFloat1(this.FP_Value[i+3])
    end
    lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, disp1, attrD)
    lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, this.FP_uom[i], TEXT_SIZE)

    lcd.drawText (LCD_COL2_HEADER + LCD_DATA_LEN, y, disp2, attrD)
    lcd.drawText (LCD_COL2_HEADER + LCD_DATA_LEN, y, this.FP_uom[i], TEXT_SIZE)
    y = y + LCD_LINE_HEIGHT
  end
end

function FlightPack.wakeup()
  local this = FlightPack

  if getFrameData(I2C_FP_BATT) then -- Specktrum Telemetry ID of data received
    -- Little Endian
    local c = getI16LE(2) --Curr 1
    if (c == -10) then c = nil end  -- (-1.0 = -10)
    this.FP_Value[0] =  c
    this.FP_Value[1] =  getI16LE(4) --Used 1
    this.FP_Value[2] =  getI16LE(6) --Temp 1

    local c = getI16LE(8) --Curr 2
    if (c == -10) then c = nil end  -- (-1.0 = -10)
    this.FP_Value[3] =  c 
    this.FP_Value[4] =  getI16LE(10) -- Used 2
    this.FP_Value[5] =  getI16LE(12) -- Temp 2
  end
end

FlightPack.event = DefaultProcessor.event

-----------------------------------------------------------------------------------


function Gps.parseGPS_Stats(pos)
  local this = Gps
  --*********** GPS STAT *********************************
  -- Example 0x17:  0  1    2  3  4  5    6    7
  --                25 00 | 00 28 15 17 | 06 | 01    
  --                Spd:002.5k, TimeUTC:17:15:28.00, Sats: 06, AltH=01      

  this.GPS_Speed =  (getBCD(pos+0) + getBCD(pos+1)*100) / 10

  local sec  = getBCD(pos+3)
  local min  = getBCD(pos+4)
  local hour = getBCD(pos+5)

  this.GPS_Time_UTC = string.format("%d:%d:%d",hour,min,sec)

  this.GPS_Sats = getBCD(pos+6);
  -- Get Altitude High since we need to combine it with Alt-Low
  -- Save the high part for later (0-99)
  this.GPS_AltHigh = getBCD(pos+7)
end


function Gps.parseGPS_Loc(pos)
  local this = Gps

  local GPS_INFO_FLAGS_IS_NORTH = 0x01
  local GPS_INFO_FLAGS_IS_EAST  = 0x02
  local GPS_INFO_FLAGS_LONGITUDE_GREATER_99 = 0x04
  
  --*********** GPS LOC *********************************
  -- Example 0x16:  0  1    2  3  4  5    6  7  8  9    10 11   12   13
  --                97 00 | 54 71 12 28 | 40 80 09 82 | 85 14 | 13 | B9
  --                Alt: 009.7, LAT: 28o 12'7154, LON: -82 09 8040 Course: 148.5, HDOP 1.3 Flags= B9

  this.GPS_Alt    =  (getBCD(pos+0) + getBCD(pos+1)*100) / 10
  this.GPS_Course =  (getBCD(pos+10) + getBCD(pos+11)*100) / 10

  local gpsFlags = getU8(pos+13);

  -- LATITUDE
  local fmin = getBCD(pos+2) + (getBCD(pos+3) * 100);
  local min  = getBCD(pos+4);
  local deg  = getBCD(pos+5);

  this.GPS_Lat_Str = string.format("%d %d.%d'",deg,min,fmin)

  -- formula from code in gps.cpp
  local value = deg * 1000000 + (min * 100000 + fmin * 10) / 6;

  if (bit32.band(gpsFlags,GPS_INFO_FLAGS_IS_NORTH) == 0) then  -- SOUTH, negative
    value = -value;
    this.GPS_Lat_Str = this.GPS_Lat_Str .. " S"
  else
    this.GPS_Lat_Str = this.GPS_Lat_Str .. " N"
  end

  this.GPS_Lat = value;
  
  -- LONGITUDE
  fmin = getBCD(pos+6) + (getBCD(pos+7) * 100);
  min = getBCD(pos+8);
  deg = getBCD(pos+9);

  if (bit32.band(gpsFlags,GPS_INFO_FLAGS_LONGITUDE_GREATER_99) ~= 0) then
    deg = deg + 100;
  end

  this.GPS_Lon_Str = string.format("%d %d.%d'",deg,min,fmin)

  -- formula from code in gps.cpp
  local value = deg * 1000000 + (min * 100000 + fmin * 10) / 6;

  if (bit32.band(gpsFlags,GPS_INFO_FLAGS_IS_EAST) == 0) then  -- WEST, negative
    value = -value;
    this.GPS_Lon_Str = this.GPS_Lon_Str .. " W"
  else
    this.GPS_Lon_Str = this.GPS_Lon_Str .. " E"
  end
  this.GPS_Lon = value;
end


function Gps.paint()
  local this = Gps

  -- draw labels and params on screen
  local y = LCD_ROW_HEADER
  local attrH2= TEXT_SIZE 
  local attrD = TEXT_SIZE + RIGHT

  lcd.clear()
  lcd.drawText (LCD_COL1_HEADER, y, "GPS", TEXT_SIZE + INVERS)

  y = y + LCD_LINE_HEIGHT + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "LAT:", attrH2)
  lcd.drawText (LCD_COL1_DATA*5, y, string.format("%f (%s)",this.GPS_Lat/1000000,this.GPS_Lat_Str), attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "LON:", attrH2)
  lcd.drawText (LCD_COL1_DATA*5, y, string.format("%f (%s)",this.GPS_Lon/1000000,this.GPS_Lon_Str), attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "Speed:", attrH2)
  lcd.drawText (LCD_COL1_DATA*3, y, string.format("%3.1f knots",this.GPS_Speed), attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "Alt:", attrH2)
  lcd.drawText (LCD_COL1_DATA*3, y, string.format("%3.1f feet",this.GPS_Alt + this.GPS_AltHigh*1000), attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "Course:", attrH2)
  lcd.drawText (LCD_COL1_DATA*3, y, string.format("%3.1f deg",this.GPS_Course), attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "Time (UTC):", attrH2)
  lcd.drawText (LCD_COL1_DATA*3, y, this.GPS_Time_UTC, attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "Sats:", attrH2)
  lcd.drawText (LCD_COL1_DATA*3, y, formatNilValue(this.GPS_Sats), attrD)
  y = y + LCD_LINE_HEIGHT
end

function Gps.wakeup()
  local this = Gps

  if (SIMULATION) then
    if (this.GPS_Step == 0) then
      FrameData   = {[0]= 0x16, 0x00, 0x25,0x00,0x00,0x28,0x15,0x17,0x06,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00}
      Gps.parseGPS_Stats(2)
      this.GPS_Step = 1
    else
      FrameData   = {[0]= 0x17, 0x00, 0x97,0x00,0x54,0x71,0x12,0x28,0x40,0x80,0x09,0x82,0x85,0x14,0x13,0xB9,0xFF}
      Gps.parseGPS_Loc(2)
      this.GPS_Step = 0
    end
    return
  end

  if (this.GPS_Step == 0) then
    if getFrameData(I2C_GPS_STATS) then -- Specktrum Telemetry ID of data received
      Gps.parseGPS_Stats(2)
      this.GPS_Step = 1
    end
  else
    if getFrameData(I2C_GPS_LOC) then -- Specktrum Telemetry ID of data received
      Gps.parseGPS_Loc(2)
      this.GPS_Step = 0
    end
  end
end

Gps.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function GpsBin.paint()
  Gps.paint()
end

function GpsBin.wakeup()
  local this = Gps

  if (SIMULATION) then
      FrameData   = {[0]=0x26,0x00,0x05,0x16,0x12,0x08,0xB6,0xB1,0xC5,0xA7,0xFF,0xFF,0x0C,0x2F,0x01}
  end

  if getFrameData(I2C_GPS_BIN) then -- Specktrum Telemetry ID of data received
    this.GPS_Alt = (getU16(2) - 1000) * 105 / 32  -- conver m to feet
    this.GPS_Lat = getI32(4) / 10
    this.GPS_Lon = getI32(8) / 10
    this.GPS_Course = (getU16(12) or 0) / 10
    this.GPS_Speed  = getU8(14) / 1.85200  -- Convert Km to Knots
    this.GPS_Sats = getU8(15) 

    this.GPS_Lat_Str = string.format("%4.10f",this.GPS_Lat / 1000000)
    this.GPS_Lon_Str = string.format("%4.10f",this.GPS_Lon / 1000000)
  end
end


GpsBin.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------

function SkyGps.paint()
  Gps.paint()
end

function SkyGps.wakeup()
  local this = Gps

  if (SIMULATION) then
    if (this.GPS_Step == 0) then
      FrameData   = {[0]= 0x27, 0x16, 0x36, 0x48, 0x28, 0x96, 0x09, 0x33, 0x72, 0x16, 0x35, 0x11, 0x00,0x00,0x28,0x3D,0x20}
      this.GPS_Step = 1
    else
      FrameData   = {[0]= 0x27, 0x17, 0x00, 0x00, 0x10, 0x17, 0x08, 0x01, 0x07, 0x00 }
      this.GPS_Step = 0
    end
    return
  end

  if getFrameData(I2C_REMOTE_ID) then -- Specktrum Telemetry ID of data received
      local packetType = getI8(1)
      if (packetType==I2C_GPS_STATS) then
        Gps.parseGPS_Stats(2)
      elseif (packetType==I2C_GPS_LOC) then
        Gps.parseGPS_Loc(2)
      end
  end
end


SkyGps.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function SkyRemoteId.paint()
  local this = SkyRemoteId

  local RID_OWNER_ID = string.sub(SkyRemoteId.RID_OwnerInfo,19)
  local DEV_SERIAL = string.sub(SkyRemoteId.RID_OwnerInfo,0,18)

  -- draw labels and params on screen
  local y = LCD_ROW_HEADER
  local attrH2= TEXT_SIZE 
  local attrD = TEXT_SIZE 

  lcd.clear()
  lcd.drawText (LCD_COL1_HEADER, y, "RemoteID", TEXT_SIZE + INVERS)

  y = y + LCD_LINE_HEIGHT + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "OWNER_INFO:", attrH2)
  lcd.drawText (LCD_COL1_DATA*2, y, SkyRemoteId.RID_OwnerInfo, attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "UAS_ID:", attrH2)
  lcd.drawText (LCD_COL1_DATA*2, y, this.RID_UAS_ID, attrD)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "DEV_INFO:", attrH2)
  lcd.drawText (LCD_COL1_DATA*2, y, this.DEV_LA0_S, attrD)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_DATA*2, y, "Hex:"..this.DEV_LA0_H, attrD)

  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Flight Status :"..this.RID_Status, attrD)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Dev Model : "..this.DEV_MODEL, attrD)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Dev Serial : "..DEV_SERIAL, attrD)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Owner ID : "..RID_OWNER_ID, attrD)
end

function SkyRemoteId.wakeup()
  local this = SkyRemoteId

  if getFrameData(I2C_REMOTE_ID) then -- Specktrum Telemetry ID of data received
      local packetType = getI8(1)
      if (packetType==I2C_REMOTE_ID) then
        this.RID_Status = getI8(2)
        local lineType  = getI8(3)
        local line      = getString(4,12,true)
    
        if (lineType == 0x00) then this.OID_L00 = line
        elseif (lineType == 0x20) then this.OID_L20 = line
        elseif (lineType == 0x40) then this.OID_L40 = line
        elseif (lineType == 0x60) then this.UAS_L60 = line
        elseif (lineType == 0x80) then this.UAS_L80 = line
        elseif (lineType == 0xA0) then 
          this.DEV_LA0_S = getString(4,12,false)
          this.DEV_LA0_H = getHexString(4,12,false)
          this.DEV_MODEL = getString(9,7,true)
        end

        this.RID_OwnerInfo = this.OID_L00 .. this.OID_L20 .. this.OID_L40
        this.RID_UAS_ID =  this.UAS_L60 .. this.UAS_L80
      end
  end
end


SkyRemoteId.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function MainScreen.init()
  local this = MainScreen
  this.ItemHighlight = 2
  this.ItemSelected  = 1
  this.Offset        = 0
end

function MainScreen.paint()
  local this    =  MainScreen

  lcd.clear()
  lcd.drawText (LCD_COL1_HEADER, LCD_ROW_HEADER, "Main Tel v"..version, TEXT_SIZE + INVERS)

  local x = LCD_COL1_DATA * 0.5

  for iParam=2 + this.Offset, #this.menu do    
    -- highlight selected parameter
    local attr = (this.ItemHighlight==iParam) and INVERS or 0
    -- set y draw coord
    local y = ((iParam-this.Offset)-1)*LCD_LINE_HEIGHT+LCD_ROW_DATA 
    
    -- Title
    local title = this.menu[iParam][1] -- Title
    lcd.drawText (x, y, title, attr + TEXT_SIZE)

    -- Draw UP/DOWN Arrows
    if ((iParam == this.Offset +  MENU_MAX_PER_PAGE) and (iParam < #this.menu)) then 
      lcd.drawText (LCD_COL1_HEADER, y, C_DOWN, TEXT_SIZE)
      break 
    elseif (iParam == this.Offset+2 and this.Offset > 0) then
      lcd.drawText (LCD_COL1_HEADER, y, C_UP, TEXT_SIZE)
    end
  end
end

function  MainScreen.event(key)
  local this    =  MainScreen

  --print("MainScreenProcessor.event() called")

  if key == EVT_VIRTUAL_PREV then
    if (this.ItemHighlight>2) then 
      this.ItemHighlight = this.ItemHighlight - 1 

      if (this.ItemHighlight <= this.Offset+1) then
        this.Offset = this.Offset - 1
      end
    end
  elseif key == EVT_VIRTUAL_NEXT then
    if (this.ItemHighlight<#this.menu) then 
      this.ItemHighlight = this.ItemHighlight + 1 

      if (this.ItemHighlight > this.Offset + MENU_MAX_PER_PAGE) then
        this.Offset = this.Offset + 1
      end
    end
  elseif key == EVT_VIRTUAL_ENTER then
    this.ItemSelected = this.ItemHighlight
  end
end

local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  local m  =  MainScreen
  local param = m.menu[m.ItemSelected][3] -- Prameter
  local Proc   = m.menu[m.ItemSelected][2] -- Processor

  -- draw specific page 
  if (Proc.paint) then
    Proc.paint(param)
  end

  if (Proc.wakeup) then
    Proc.wakeup(param)
  end

  if event == EVT_VIRTUAL_EXIT then
    if (m.ItemSelected==1) then -- on Main?? Exit Script
      closeTelemetryRaw()
      return 1 
    end   
  end

  if (Proc.event) then
    Proc.event(event)
  end

  return 0
end

local function init()

  if (LCD_W <= 128 or LCD_H <=64) then -- Smaller Screens 
    TEXT_SIZE             = SMLSIZE 
    TEXT_SIZE_BIG         = DBLSIZE
    LCD_COL1_HEADER         = 1
    LCD_COL1_DATA           = 20

    LCD_COL2_HEADER         = 60
    LCD_COL2_DATA           = 90

    LCD_DATA_LEN            = 28 
    LCD_DATA_SPACE          = 1


    --Y_LINE_HEIGHT         = 8
    
    C_UP                 = "^"
    C_DOWN               = "v"

    MENU_MAX_PER_PAGE    = 6
    LCD_LINE_HEIGHT      = 8
  else
    MENU_MAX_PER_PAGE     = 7
    local tw, th = lcd.sizeText("", TEXT_SIZE)
    LCD_LINE_HEIGHT  = th + 1
  end

  LCD_ROW_DATA       = LCD_ROW_HEADER + LCD_LINE_HEIGHT
end

return { run=run,  init=init  }
