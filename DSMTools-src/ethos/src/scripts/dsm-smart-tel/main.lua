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

local translations = {en="DSM Tel 1.4"}

local SIMULATION            = false

local TEXT_SIZE             = FONT_STD
local TEXT_SIZE_BIG         = FONT_BOLD
local LCD_COL1_HEADER       = 6
local LCD_COL1_DATA         = 60
local LCD_COL2_HEADER       = 170
local LCD_COL2_DATA         = 220
local LCD_LINE_HEIGHT       = 20
local LCD_ROW_HEADER        = 0
local LCD_ROW_DATA          = LCD_ROW_HEADER + LCD_LINE_HEIGHT*2 
local LCD_DATA_LEN          = 80 
local LCD_DATA_SPACE        = 5

local LCD_TEXT_COLOR         = lcd.themeColor(THEME_DEFAULT_COLOR)
local LCD_FOCUS_COLOR        = lcd.themeColor(THEME_FOCUS_COLOR)

local C_UP                  = "^"
local C_DOWN                = "v"

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


local multiSensor           = nil

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
  --Init telemetry Queue
  if (multiSensor==nil) then
    multiSensor = multimodule.getSensor()
  end
end

local function closeTelemetryRaw()
  multiSensor = nil
end

local function getFrameData(I2C_ID) 
  local data = nil

  if (SIMULATION) then
    if (I2C_ID == I2C_QOS) then
        data = { 0x7F,0x00,0x00,0x5A,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x02,0x03,0x01 }
    end
  else
  --data =  multiSensor:popFrame({i2cAddress=I2C_ID})
    data =  multiSensor:popFrame()
  end


  if (data) then
    local i2cId = data[1] or 0
    if (I2C_ID > 0 and i2cId ~= I2C_ID) then   -- not the data we want?
      data = nil
    end
  end

  if (data) then
    for i=1,16 do  -- Copy from 1 based array into 0 base array
      FrameData[i-1] = data[i] or 0xFF
    end
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
     local val = FrameData[p] + (FrameData[p+1] << 8)
     if (val == I16_NODATA) then return nil else return Unsigned_to_SInt16(val) end
end

local function getU16LE(p)
  local val = FrameData[p] + (FrameData[p+1] << 8)
  if (val == U16_NODATA) then return nil else return val end
end

local function getU16(p)
  local val = (FrameData[p] << 8) + FrameData[p+1]
  if (val == U16_NODATA) then return nil else return val end
end

local function getI16(p)
  local val = (FrameData[p] << 8) + FrameData[p+1]
  if (val == I16_NODATA) then return nil else return val end
end

local function getI32(p)
  local val = (FrameData[p] << 24) + (FrameData[p+1] << 16) + 
              (FrameData[p+2] << 8)  + FrameData[p+3]
  local mask = 0x80000000
  val = (val ~ mask) - mask
  if (val == I32_NODATA) then return nil else return val end
end

local function getU32LE(p)
  local val = (FrameData[p+3] << 24) + (FrameData[p+2] << 16) + 
              (FrameData[p+1] << 8)  + FrameData[p]
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
  local d1 = (ch >> 4) & 0x0F
  local d2 = ch & 0x0F

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
  if key == KEY_RTN_BREAK then
      MainScreen.ItemSelected = 1 -- Main Menu
      lcd.invalidate()
  end
end

-----------------------------------------------------------------------------------

function FlightLog.wakeup()
  local this = FlightLog

  if getFrameData(I2C_QOS) then
    this.QOS_Value[0] = getU16(2) -- A
    this.QOS_Value[1] = getU16(4) -- B
    this.QOS_Value[2] = getU16(6) -- L
    this.QOS_Value[3] = getU16(8) -- R 
    this.QOS_Value[4] = getU16(10) -- F
    
    local holds = getU16(12)   -- H
    if (holds == I16_NODATA) then holds = nil end
    this.QOS_Value[5] = holds

    this.QOS_Value[6] = getU16(14) -- Bat

    lcd.invalidate()
  end
end

function FlightLog.paint()  
  -- draw labels and params on screen
  local this = FlightLog
  
  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, LCD_ROW_HEADER, "Flight Log")

  local activeParam = (this.QOS_Value[5] or 0) - 1 -- H 

  local y = LCD_LINE_HEIGHT+LCD_ROW_DATA

  for iParam=0,3 do   -- A,B,L,R 
    lcd.color(LCD_TEXT_COLOR)
    
  
    -- highlight selected parameter  (rund)
    if ((activeParam % 4)==iParam) then
      lcd.color(LCD_FOCUS_COLOR)
    end

    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER, y, this.QOS_Title[iParam])
    
    -- Values
    local val = this.QOS_Value[iParam] 
    if (val==0x4000) then  -- Active value
        lcd.color(LCD_FOCUS_COLOR)
        lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, "  ", RIGHT)
    else
        lcd.font(FONT_STD)
        lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, formatNilValue(val), RIGHT)
    end

    y = y + LCD_LINE_HEIGHT
  end

  y = LCD_LINE_HEIGHT+LCD_ROW_DATA
  for iParam=4,5 do  -- F, H
    lcd.font(FONT_L)
    lcd.drawText (LCD_COL2_HEADER, y, this.QOS_Title[iParam])
    lcd.drawText (LCD_COL2_DATA + LCD_DATA_LEN, y, formatNilValue(this.QOS_Value[iParam]), RIGHT)
    y = y + LCD_LINE_HEIGHT*2
  end

  -- Bat 
  local bat = this.QOS_Value[6]
  if (bat ~= nil) then bat = string.format("%0.2f", bat/100) else bat = "--" end
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL2_HEADER, y, "Bat:")
  lcd.drawText (LCD_COL2_DATA + LCD_DATA_LEN, y, bat, RIGHT)
  lcd.drawText (LCD_COL2_DATA + LCD_DATA_LEN + LCD_DATA_SPACE, y, " v")
end

FlightLog.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function AS3XSettings.paint(page)
  local this =  AS3XSettings
  
  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  if (page==1) then
    lcd.drawText (1,0, "AS3X Settings")
  else
    lcd.drawText (1,0, "SAFE Limits")
  end

  local y = LCD_ROW_DATA
  -- Flight Mode
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_HEADER,y, "FM: "..this.AS3X_FmMsg)
  lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN*0.4,y, "Flags: "..formatNilValue(this.AS3X_Flags))
  lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN*0.7,y, "State: "..formatNilValue(this.AS3X_State))

  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER,y, this.AS3X_FlagsMsg)

  y = y + LCD_LINE_HEIGHT

  if (fm == 0xE) then
    return
  end

  if (page==1) then
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER+LCD_DATA_LEN*0.3,y, "AS3X Gains")
    lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN*0.3,y, "AS3X Headings")
    
    y = y + LCD_LINE_HEIGHT
    lcd.drawText (LCD_COL1_HEADER,y, "Roll:")
    lcd.font(FONT_STD)
    lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[0]), RIGHT) -- Roll G 
    lcd.drawText (LCD_COL2_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[3]), RIGHT) -- Roll H 

    y = y + LCD_LINE_HEIGHT
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER,y, "Pitch:")
    lcd.font(FONT_STD)
    lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[1]), RIGHT)  -- Pitch G
    lcd.drawText (LCD_COL2_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[4]), RIGHT) -- Pitch H 

    y = y + LCD_LINE_HEIGHT
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER,y, "Yaw:", TEXT_SIZE)
    lcd.font(FONT_STD)
    lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[2]), RIGHT) -- Yaw G
    lcd.drawText (LCD_COL2_DATA+LCD_DATA_LEN,y, formatNilValue(this.AS3X_Data[5]), RIGHT) -- Yaw H
  end


  if (page==2) then
    local x_data1 = LCD_COL1_DATA+LCD_DATA_LEN
    local x_data2 = LCD_COL2_HEADER+LCD_DATA_LEN*1.6

    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER+LCD_DATA_LEN*0.3,y, "SAFE Gains")
    lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN*0.1,y, "Angle Limits")
  
    y = y + LCD_LINE_HEIGHT
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER,y, "Roll:")
    lcd.font(FONT_STD)
    lcd.drawText (x_data1,y, formatNilValue(this.AS3X_Data[6]), RIGHT)

    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL2_HEADER,y, "Roll R:")
    lcd.font(FONT_STD)
    lcd.drawText (x_data2,y, formatNilValue(this.AS3X_Data[12]), RIGHT)


    y = y + LCD_LINE_HEIGHT
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER,y, "Pitch:")
    lcd.font(FONT_STD)
    lcd.drawText (x_data1,y,formatNilValue(this.AS3X_Data[7]), RIGHT)

    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL2_HEADER,y, "Roll L:" )
    lcd.font(FONT_STD)
    lcd.drawText (x_data2,y,formatNilValue(this.AS3X_Data[13]), RIGHT)


    y = y + LCD_LINE_HEIGHT
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER,y, "Yaw:")
    lcd.font(FONT_STD)
    lcd.drawText (x_data1,y, formatNilValue(this.AS3X_Data[8]), RIGHT)

    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL2_HEADER,y, "Pitch U:")
    lcd.font(FONT_STD)
    lcd.drawText (x_data2,y, formatNilValue(this.AS3X_Data[14]), RIGHT)

    y = y + LCD_LINE_HEIGHT
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL2_HEADER,y, "Pitch D:")
    lcd.font(FONT_STD)
    lcd.drawText (x_data2,y, formatNilValue(this.AS3X_Data[15]), RIGHT)
  end
end

function AS3XSettings.wakeup()
  local this =  AS3XSettings

  if  getFrameData(I2C_FLITECTRL) then
    this.AS3X_FlagsMsg=""

    this.AS3X_Flags = getU8(2)
    this.AS3X_State = getU8(3)

    local fm =   FrameData[4] & 0xF
    local axis = FrameData[5] & 0xF  -- 0=Gains,1=Headings,2=Angle Limits (cointinus iterating to provide all values)
  
    if (fm ~= 0x0E) then
      local separator=""
      
      this.AS3X_FmMsg = ""..(fm+1)
      -- flags bits:  Safe Envelop, ?, Angle Demand, Stab 
      if (this.AS3X_Flags & 0x1 ~= 0) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg.."AS3X Stab"; separator=", " end
      -- This one, only one should show
      if (this.AS3X_Flags & 0x2 ~=0) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg..separator.."Safe Level" 
      elseif (this.AS3X_Flags & 0x8 ~=0 ) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg..separator.."Safe Envelope" 
      elseif (this.AS3X_Flags & 0x4 ~=0 ) then this.AS3X_FlagsMsg=this.AS3X_FlagsMsg..separator.."Heading" end
  
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

  lcd.invalidate()
end

AS3XSettings.event = DefaultProcessor.event

-----------------------------------------------------------------------------------
function SmartESC.paint()
  local this = SmartESC

  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  lcd.drawText (1,0, "ESC")

  local y = 0
  local x_data = LCD_COL1_DATA+LCD_DATA_LEN*1.5
  local x_data2 = LCD_COL2_DATA+LCD_DATA_LEN*0.5
  local x_data3 = x_data2 + LCD_DATA_LEN*0.8

  lcd.font(FONT_BOLD)
  lcd.drawText (x_data,y , "Status", RIGHT)
  lcd.drawText (x_data2,y, "Min", RIGHT)
  lcd.drawText (x_data3,y, "Max", RIGHT)
  
  y = LCD_ROW_DATA
  for i=1,9 do
      lcd.font(FONT_BOLD)
      lcd.drawText (LCD_COL1_HEADER,y, this.ESC_Title[i])

      local val = this.ESC_Value[i]
      local min = this.ESC_Min[i]
      local max = this.ESC_Max[i]
      if (i==1) then -- RPM
        val = formatWithComma(val)
        min = formatWithComma(min)
        max = formatWithComma(max)
      end

      lcd.font(FONT_STD)
      lcd.drawText (x_data,y, formatNilValue(val), RIGHT)
      lcd.drawText (x_data,y, this.ESC_uom[i])
      lcd.drawText (x_data2,y, formatNilValue(min), RIGHT)
      lcd.drawText (x_data3,y, formatNilValue(max), RIGHT)
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

      lcd.invalidate()
  end
end

SmartESC.event = DefaultProcessor.event

-----------------------------------------------------------------------------------
function SmartBat.paint()
  local this = SmartBat

  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  lcd.drawText (1,0, "Battery Stats")
  
  local y = LCD_ROW_DATA
  local x_data = LCD_COL1_DATA+LCD_DATA_LEN+LCD_DATA_SPACE*3
  for i=1,6 do
      lcd.font(FONT_BOLD)
      lcd.drawText (LCD_COL1_HEADER, y, this.BAT_Title[i])
      lcd.font(FONT_STD)
      lcd.drawText (x_data, y, formatNilValue(this.BAT_Values[i]), RIGHT)
      lcd.drawText (x_data+LCD_DATA_SPACE, y, this.BAT_uom[i])
      y = y + LCD_LINE_HEIGHT
  end

  y = LCD_ROW_DATA
  x_data = LCD_COL2_DATA+LCD_DATA_LEN+LCD_DATA_SPACE*5
  for i=0,8 do
      if ((this.BAT_Cells[i] or 0) > 0) then
        lcd.font(FONT_BOLD)
        lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN/2,y, "Cel "..(i+1)..":")
        lcd.font(FONT_STD)
        lcd.drawText (x_data,y, string.format("%2.2f",this.BAT_Cells[i]), RIGHT)
        lcd.drawText (x_data+LCD_DATA_SPACE,y, "v")
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

    lcd.invalidate()
  end
end

SmartBat.event = DefaultProcessor.event

-----------------------------------------------------------------------------------

function TextGen.paint()
  local this = TextGen

  lcd.color(LCD_TEXT_COLOR)

  local y = LCD_ROW_DATA
  local x = LCD_COL1_HEADER
  local hAttr = 0

  if (LCD_Y_MAX <= 64) then 
    -- Need to be able to show 8 lines of data + heather
    -- show header on the right hand side to gain 1 line
    x = 128
    y = 0
    hAttr = hAttr + RIGHT
  else
    y = LCD_ROW_DATA + LCD_LINE_HEIGHT
  end

  lcd.font(FONT_BOLD)
  lcd.drawText (x,0, "TextGen", hAttr)
  if (this.TG_Lines[0]) then   -- Header
    lcd.drawText (x,LCD_LINE_HEIGHT, this.TG_Lines[0], hAttr)
  end

  -- Menu lines
  lcd.font(FONT_STD)
  for i=1,8 do
    if (this.TG_Lines[i]) then
      lcd.drawText (LCD_COL1_HEADER,y,  this.TG_Lines[i])
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

  lcd.invalidate()
end


function TextGen.event(key)
  if key == KEY_RTN_BREAK then -- Exit?? Clear menu data
    DefaultProcessor.event(key)
  end
end

-----------------------------------------------------------------------------------

function FlightPack.paint()
  local this = FlightPack
  -- draw labels and params on screen
  local y = LCD_ROW_HEADER

  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "Flight Pack")

  y = y + LCD_LINE_HEIGHT + LCD_LINE_HEIGHT
  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_DATA+LCD_DATA_LEN, y, "Batt 1", RIGHT)
  lcd.drawText (LCD_COL2_HEADER+LCD_DATA_LEN, y, "Batt 2", RIGHT)

  y = y + LCD_LINE_HEIGHT


  for i=0,2 do
    lcd.font(FONT_BOLD)
    lcd.drawText (LCD_COL1_HEADER, y, this.FP_Title[i])

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
    lcd.font(FONT_STD)
    lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, disp1, RIGHT)
    lcd.drawText (LCD_COL1_DATA + LCD_DATA_LEN, y, this.FP_uom[i])

    lcd.drawText (LCD_COL2_HEADER + LCD_DATA_LEN, y, disp2, RIGHT)
    lcd.drawText (LCD_COL2_HEADER + LCD_DATA_LEN, y, this.FP_uom[i])
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

    lcd.invalidate()
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

  if ((gpsFlags & GPS_INFO_FLAGS_IS_NORTH) == 0) then  -- SOUTH, negative
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

  if ((gpsFlags & GPS_INFO_FLAGS_LONGITUDE_GREATER_99) ~= 0) then
    deg = deg + 100;
  end

  this.GPS_Lon_Str = string.format("%d %d.%d'",deg,min,fmin)

  -- formula from code in gps.cpp
  local value = deg * 1000000 + (min * 100000 + fmin * 10) / 6;

  if ((gpsFlags & GPS_INFO_FLAGS_IS_EAST) == 0) then  -- WEST, negative
    value = -value;
    this.GPS_Lon_Str = this.GPS_Lon_Str .. " W"
  else
    this.GPS_Lon_Str = this.GPS_Lon_Str .. " E"
  end
  this.GPS_Lon = value
end


function Gps.paint()
  local this = Gps

  -- draw labels and params on screen
  local y = LCD_ROW_HEADER


  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "GPS")

  y = y + LCD_LINE_HEIGHT + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "LAT:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*5, y, string.format("%f (%s)",this.GPS_Lat/1000000,this.GPS_Lat_Str), RIGHT)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "LON:")
  lcd.drawText (LCD_COL1_DATA*5, y, string.format("%f (%s)",this.GPS_Lon/1000000,this.GPS_Lon_Str), RIGHT)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "Speed:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*3, y, string.format("%3.1f knots",this.GPS_Speed), RIGHT)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "Alt:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*3, y, string.format("%3.1f feet",this.GPS_Alt + this.GPS_AltHigh*1000), RIGHT)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "Course:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*3, y, string.format("%3.1f deg",this.GPS_Course), RIGHT)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "Time (UTC):")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*3, y, this.GPS_Time_UTC, RIGHT)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "Sats:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*3, y, formatNilValue(this.GPS_Sats), RIGHT)
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
    lcd.invalidate()
    return
  end

  if (this.GPS_Step == 0) then
    if getFrameData(I2C_GPS_STATS) then -- Specktrum Telemetry ID of data received
      Gps.parseGPS_Stats(2)
      this.GPS_Step = 1
      lcd.invalidate()
    end
  else
    if getFrameData(I2C_GPS_LOC) then -- Specktrum Telemetry ID of data received
      Gps.parseGPS_Loc(2)
      this.GPS_Step = 0
      lcd.invalidate()
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

  if SIMULATION or getFrameData(I2C_GPS_BIN) then -- Specktrum Telemetry ID of data received
    this.GPS_Alt = (getU16(2) - 1000) * 105 / 32  -- conver m to feet
    this.GPS_Lat = getI32(4) / 10
    this.GPS_Lon = getI32(8) / 10
    this.GPS_Course = (getU16(12) or 0) / 10
    this.GPS_Speed  = getU8(14) / 1.85200  -- Convert Km to Knots
    this.GPS_Sats = getU8(15) 

    this.GPS_Lat_Str = string.format("%4.10f",this.GPS_Lat / 1000000)
    this.GPS_Lon_Str = string.format("%4.10f",this.GPS_Lon / 1000000)

    lcd.invalidate()
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
      Gps.parseGPS_Loc(2)
    else
      FrameData   = {[0]= 0x27, 0x17, 0x00, 0x00, 0x10, 0x17, 0x08, 0x01, 0x07, 0x00 }
      Gps.parseGPS_Stats(2)
      this.GPS_Step = 0
    end
    
    lcd.invalidate()
    return
  end

  if getFrameData(I2C_REMOTE_ID) then -- Specktrum Telemetry ID of data received
      local packetType = getI8(1)
      if (packetType==I2C_GPS_STATS) then
        Gps.parseGPS_Stats(2)
      elseif (packetType==I2C_GPS_LOC) then
        Gps.parseGPS_Loc(2)
      end
      lcd.invalidate()
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

  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "RemoteID")

  y = y + LCD_LINE_HEIGHT + LCD_LINE_HEIGHT
  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "OWNER_INFO:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*2, y, SkyRemoteId.RID_OwnerInfo)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "UAS_ID:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*2, y, this.RID_UAS_ID)
  y = y + LCD_LINE_HEIGHT

  lcd.font(FONT_BOLD)
  lcd.drawText (LCD_COL1_HEADER, y, "DEV_INFO:")
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*2, y, this.DEV_LA0_S)
  y = y + LCD_LINE_HEIGHT
  
  lcd.font(FONT_STD)
  lcd.drawText (LCD_COL1_DATA*2, y, "Hex:"..this.DEV_LA0_H)
  y = y + LCD_LINE_HEIGHT

  lcd.drawText (LCD_COL1_HEADER, y, "Flight Status :"..this.RID_Status)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Dev Model : "..this.DEV_MODEL)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Dev Serial : "..DEV_SERIAL)
  y = y + LCD_LINE_HEIGHT
  lcd.drawText (LCD_COL1_HEADER, y, "Owner ID : "..RID_OWNER_ID)
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
      lcd.invalidate()
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

  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)

  lcd.drawText (LCD_COL1_HEADER, LCD_ROW_HEADER, "Main Tel (Smart RXs) v1.4")

  local x = LCD_COL1_DATA * 0.5

  for iParam=2 + this.Offset, #this.menu do    
    lcd.color(LCD_TEXT_COLOR)
    lcd.font(FONT_STD)

    -- highlight selected parameter
    if (this.ItemHighlight==iParam) then
      lcd.color(LCD_FOCUS_COLOR)
      lcd.font(FONT_BOLD)
    end

    -- set y draw coord
    local y = (iParam-this.Offset)*LCD_LINE_HEIGHT+LCD_ROW_DATA 
    
    -- Title
    local title = this.menu[iParam][1] -- Title
    lcd.drawText (x, y, title)

    -- Draw UP/DOWN Arrows
    if ((iParam == this.Offset +  MENU_MAX_PER_PAGE) and (iParam < #this.menu)) then 
      lcd.drawText (LCD_COL1_HEADER, y, C_DOWN)
      break 
    elseif (iParam == this.Offset+2 and this.Offset > 0) then
      lcd.drawText (LCD_COL1_HEADER, y, C_UP)
    end
  end
end

function  MainScreen.event(key)
  local this    =  MainScreen

  --print("MainScreenProcessor.event() called")

  if key == KEY_ROTARY_LEFT then
    if (this.ItemHighlight>2) then 
      this.ItemHighlight = this.ItemHighlight - 1 

      if (this.ItemHighlight <= this.Offset+1) then
        this.Offset = this.Offset - 1
      end
    end
  elseif key == KEY_ROTARY_RIGHT then
    if (this.ItemHighlight<#this.menu) then 
      this.ItemHighlight = this.ItemHighlight + 1 

      if (this.ItemHighlight > this.Offset + MENU_MAX_PER_PAGE) then
        this.Offset = this.Offset + 1
      end
    end
  elseif key == KEY_ENTER_BREAK then
    this.ItemSelected = this.ItemHighlight
  end

  lcd.invalidate()
end

---------------------------------------------------------------------------------------------

local function name(widget)
  local locale = system.getLocale()
  return translations[locale] or translations["en"]
end

local function create()
  print("create() called")

  LCD_X_MAX, LCD_Y_MAX = lcd.getWindowSize()
  
  -- Recompute line positions
  if (LCD_X_MAX <= 128 or LCD_Y_MAX <=64) then -- Smaller Screens 
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

    MENU_MAX_PER_PAGE    = 5
  else
    MENU_MAX_PER_PAGE     = 7
  end

  lcd.font(FONT_STD)
  local tw, th = lcd.getTextSize("")
  LCD_LINE_HEIGHT  = th + 1
  LCD_ROW_DATA       = LCD_ROW_HEADER + LCD_LINE_HEIGHT
  openTelemetryRaw() 

  return {}
end

local function wakeup(widget)
  local m  =  MainScreen
  local param = m.menu[m.ItemSelected][3] -- Prameter
  local Proc   = m.menu[m.ItemSelected][2] -- Processor

  if (Proc.wakeup) then
    Proc.wakeup(param)
  end
end

local function paint(widget)
  --print("paint() called")
  local m  =  MainScreen
  local param = m.menu[m.ItemSelected][3] -- Prameter
  local Proc   = m.menu[m.ItemSelected][2] -- Processor

  if (Proc.paint) then
    Proc.paint(param)
  end
end

local function event(widget, category, value, x, y)
  --print("Event received:", category, value, x, y)
  if category == EVT_KEY then
    local m  =  MainScreen
    local param = m.menu[m.ItemSelected][3] -- Prameter
    local Proc   = m.menu[m.ItemSelected][2] -- Processor

    if (value == KEY_RTN_LONG) then  -- Exit??
      closeTelemetryRaw()
      system.exit()
    elseif (value == KEY_RTN_BREAK) then
      if (m.ItemSelected==1) then -- on Main?? Exit Script
        closeTelemetryRaw()
        system.exit()  
      end
    end

  

    if (Proc.event) then
      Proc.event(value)
    end
  end
  return true
end

local icon = lcd.loadMask("icon.png")

local function init()
  --print("init() called")
  system.registerSystemTool({name=name, icon=icon, create=create, wakeup=wakeup, event=event, paint=paint})
end

return {init=init}
