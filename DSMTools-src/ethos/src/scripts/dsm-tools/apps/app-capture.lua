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
 
local arg = {...}

local config = arg[1]

local SIMULATION <const> = config.simulation
local sim                   = nil  -- lazy load the sim-lib when needed
--
-- Computed at Create
local LCD_W                 = 0
local LCD_H                 = 0
local LCD_LINE_H            = 0

local LOG_FILE = config.logPath .. "dsm_raw_tel.txt"
local logFile = nil 

local multiSensor = nil 
    
local CaptureProcessor = {
  firstCapture = true,
  lineCount=0,
  headerHex="",
  debugHex="",
}

local MainScreenProcessor = {
  telPage = 0,             -- Current Menu Pos
  telPageSelected = 0,     -- Active Page  
}

MainScreenProcessor.menu = {
    {"Main Menu ",             MainScreenProcessor, 0  }, 
    {"Quality of Signal 0x7F", CaptureProcessor,  0x7F },
    {"TextGen (0x0C)",         CaptureProcessor,  0x0C },
    {"RPM/Volts (0x7E)",       CaptureProcessor,  0x7E },
    {"Flight Pack (0x34)",     CaptureProcessor,  0x34 },
    {"Flight-Ctlr (0x05)",     CaptureProcessor,  0x05 },
    {"ESC (0x20)",             CaptureProcessor,  0x20 },
    {"Smart Bat (0x42)",       CaptureProcessor,  0x42 },
    {"Vario (0x40)",           CaptureProcessor,  0x40 },
    {"PowerBox (0x0A)",        CaptureProcessor,  0x0A },
    {"SkyID (0x27)",           CaptureProcessor,  0x27 },
    {"GPS-Loc (0x16)",         CaptureProcessor,  0x16 },
    {"GPS-Stat (0x17)",        CaptureProcessor,  0x17 },
    {"GPS-Bin (0x26)",         CaptureProcessor,  0x26 }
}

---------------------------------------------------------------------------------------------

local function LOG_open()  
    logFile = assert(io.open(LOG_FILE, "a"),"Cannot Open Log")  -- Truncate Log File 
end

local function LOG_write(...)
    if (logFile==nil) then LOG_open() end

    local str = string.format(...)
    assert(io.write(logFile, str),"Can't write to log")
    print(str)
end

local function LOG_close()
    if (logFile~=nil) then io.close(logFile); logFile = nil end
end

---------------------------------------------------------------------------------------------

local function openTelemetryRaw()
    --Init telemetry Queue
    if (SIMULATION and sim==nil) then
      print("Loading Simulator")
      sim = assert(loadfile(config.libPath.."lib-sim-telemetry-data.lua"))()
    elseif (multiSensor==nil) then
       multiSensor = multimodule.getSensor()
    end
end

local function closeTelemetryRaw()
    multiSensor = nil
    sim = nil
end

local function getTelemetryFrame(I2C_ID)
    -- The inbound Frame has the following format starting at index 1:
    -- MultiModule Header: [1]=RSSI,[2]=Type,[3]=???, 
    -- Data: [4...19]= data for that frame, starting with I2C_ID

    local data

    if (SIMULATION) then
      data = sim.getFrameData(I2C_ID)
    else
      data = multiSensor:popFrame({i2cAddress=I2C_ID})
    end

  return data
end

---------------------------------------------------------------------------------------------

function CaptureProcessor.init(i2cID)
  local w, h = lcd.getWindowSize()
  print("CaptureProcessor.init()")
  local this = CaptureProcessor
  this.firstCapture = true
  this.lineCount=0
  this.debugHex=""

  form.clear()
  local line = form.addLine(string.format("Capturing Data I2C=0x%02x",i2cID))
  form.addTextButton(line, nil, "RTN", function() CaptureProcessor.close() end)

  lcd.font(FONT_STD)
  local tw, th = lcd.getTextSize("X")

  local leftCoords = {x=1,y=1,w=w,h=th * 1.2}

  leftCoords.y = form.height()
  leftCoords.x =  (w - lcd.getTextSize("Line: ")) // 2 -- Centered
  this.lineText = form.addStaticText(nil,  leftCoords, "Line : ")

  leftCoords.y = form.height()
  leftCoords.x = 1
  this.headerText = form.addStaticText(nil, leftCoords, "")

  leftCoords.y = form.height()
  this.dataText = form.addStaticText(nil, leftCoords, "")

end

function CaptureProcessor.close()
  MainScreenProcessor.telPageSelected = 1  -- any page, return to Main
  --form.clear()
  --lcd.invalidate()
  MainScreenProcessor.init()
end

function CaptureProcessor.paint(I2C_ID)
end -- Paint

function CaptureProcessor.wakeup(I2C_ID)
  --print("CaptureProcessor.wakeup() called")
  local this = CaptureProcessor

  if (this.firstCapture) then -- First time run???
    this.firstCapture = false
    LOG_close()
    LOG_open()
    LOG_write("--------- Capturing I2C_ID %2X\n",I2C_ID)
  end

  -- Proces Telementry message
  local data = getTelemetryFrame(I2C_ID)

  if (data ~= nil) then   
      this.debugHex = ""
      this.debugHexForCode = ""

      this.headerHex = ""
      this.headerHexForCode = ""

      for i=1,3 do
        local sep = (i==3 and "") or ","
        this.headerHexForCode= this.headerHexForCode .. string.format("0x%02X%s", (data[i] or 0xFF),sep)
        this.headerHex       = this.headerHex        .. string.format("%02X ", (data[i] or 0xFF))
      end

      for i=4,19 do
          local sep = (i==19 and "") or ","
          this.debugHexForCode= this.debugHexForCode .. string.format("0x%02X%s", (data[i] or 0xFF),sep)
          this.debugHex       = this.debugHex        .. string.format("%02X ", (data[i] or 0xFF))
      end

      this.lineCount=this.lineCount+1
      LOG_write("%s,   %s\n",this.headerHexForCode, this.debugHexForCode)

      this.lineText:value(string.format("Lines: %d",this.lineCount))
      this.headerText:value(this.headerHex)
      this.dataText:value(this.debugHex)

      form.invalidate()
      --lcd.invalidate()
  end
end -- Wakeup

function CaptureProcessor.event(I2C_ID, category, key)
  --print("CaptureProcessor.event() called")
  local this = CaptureProcessor

  if (key == KEY_RTN_BREAK) then
    CaptureProcessor.close()
    return true
  end
  return false
end

---------------------------------------------------------------------------------------------

function MainScreenProcessor.init()
  local this = MainScreenProcessor
  this.telPageSelected = 1
  this.telPage = 2

  -- Dynamically Resize Buttons
  local buttonHeight = LCD_LINE_H * 2
  local buttonWidth = LCD_W / 4
  local buttonHeightPadding = LCD_LINE_H // 4
  local buttonWidthPadding = buttonWidth // 4

  form.clear()
  local line = form.addLine("Telemetry Raw Capture")
  form.addTextButton(line, {x=LCD_W-80,y=5,w=75,h=LCD_LINE_H*1.2}, "Back", function() config.exit() end)

  local sectionHeight = form.height() + 10

  for iParam=2, #this.menu do    
    -- Convert X,Y 3x7 matrix
     local menuPos = iParam-2
     local menuCol =  menuPos % 3 
     local menuRow =  menuPos // 3 

     local xOffset = 10 + menuCol * (buttonWidth +buttonWidthPadding)
     local vOffset = sectionHeight + menuRow * (buttonHeight + buttonHeightPadding)
     
     local button  = form.addButton(nil, {x = xOffset , y = vOffset , w = buttonWidth, h = buttonHeight}, 
     {
      text = this.menu[iParam][1],
      icon = nil, -- you can load a mask and put an image into the button
      options = nil, -- FONT_S,
      press = function()
          this.telPageSelected = iParam -- Activate current page
          local proc   = this.menu[iParam][2]
          local param = this.menu[iParam][3]
          proc.init(param) -- Init of Processor 
      end
    })

  end
end

function MainScreenProcessor.paint(I2C_ID)
  -- Everything is done by the form 
end

function  MainScreenProcessor.event(I2C_ID, category, key)
  local this    =  MainScreenProcessor
  local ret     =  false

  --print("MainScreenProcessor.event() called")
  return ret
end

---------------------------------------------------------------------------------------------

local function create()
  print("capture.create() called")
  
  lcd.font(FONT_STD)

  lcd.setWindowTitle("Telemery Capture")
  LCD_W, LCD_H  = lcd.getWindowSize()
  local tw,th = lcd.getTextSize("")

  LCD_LINE_H   = th
  
  openTelemetryRaw() 

  MainScreenProcessor.init()
  return {}
end

local function close()
  print("capture.close()")
  closeTelemetryRaw()
  LOG_close()
end

local function wakeup(widget)
  local m  =  MainScreenProcessor
  local Proc   = m.menu[m.telPageSelected][2]
  local params = m.menu[m.telPageSelected][3]
  

  if (Proc.wakeup) then
    Proc.wakeup(params)
  end
end

local function paint(widget)
  --print("paint() called")
  local m  =  MainScreenProcessor
  local Proc   = m.menu[m.telPageSelected][2]
  local params = m.menu[m.telPageSelected][3]
  
  if (Proc.paint) then
    Proc.paint(params)
  end
end

local function event(widget, category, value, x, y)
  --print("Event received:", category, value, x, y)
  if category == EVT_KEY then
    --if (value == KEY_RTN_LONG) then  -- Exit??    
    --  system.exit()
    --  return true
    --end

    local m  =  MainScreenProcessor
    local Proc   = m.menu[m.telPageSelected][2]
    local params = m.menu[m.telPageSelected][3]
  
    if (Proc.event) then
      return Proc.event(params, category, value)
    end
  end
  return false
end

return {create=create, close=close, wakeup=wakeup, event=event, paint=paint}