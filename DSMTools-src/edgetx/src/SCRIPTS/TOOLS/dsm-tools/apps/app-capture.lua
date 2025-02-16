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
local ui = arg[2]
local form = arg[3]

local SIMULATION            = config.simulation
local sim                   = nil  -- lazy load the sim-lib when needed
--
-- Computed at Create
local LCD_LINE_H            = 0

local LOG_FILE = config.logPath .. "dsm_raw_tel.txt"
local logFile = nil 
    
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
---
local function openTelemetryRaw()
  --Init telemetry Queue
  if (SIMULATION and sim == nil) then
    print("Loading Simulator")
    sim = assert(loadfile(config.libPath.."lib-sim-telemetry-data.lua"))()
  else
      --Init telemetry  (Spectrun Telemetry Raw STR)
      multiBuffer( 0, string.byte('S') )
      multiBuffer( 1, string.byte('T') )
      multiBuffer( 2, string.byte('R') ) 
      multiBuffer( 3, 0 ) -- Monitor this teemetry data I2C ID
      multiBuffer( 4, 0 ) -- Allow to get Data
  end
end

local function closeTelemetryRaw()
  multiBuffer(0, 0) -- Destroy the STR header 
  multiBuffer(3, 0) -- Not requesting any Telementry ID
  sim = nil
end

local function getFrameData(I2C_ID) 
  local data = nil

  if (SIMULATION) then
    local simData = sim.getFrameData(I2C_ID)
    if (simData) then 
      data = {}
      for i=0,15 do
        data[i] = simData[i+1]  -- data from GetFrameData is 1 base array
      end
    end
  else
    if (multiBuffer(3) ~= I2C_ID ) then -- Switch I2C ID?
      multiBuffer( 3, I2C_ID ) -- Monitor this teemetry data
      multiBuffer( 4, 0 ) -- Allow to get Data
    end
  
    if multiBuffer( 4 ) == I2C_ID then
      data = {}
      for i=0,15 do
        data[i] = multiBuffer(4+i)
      end
      multiBuffer( 4, 0 ) -- Allow to get Data
    end
  end

  return data
end
---------------------------------------------------------------------------------------------

function CaptureProcessor.init(i2cID)
  print("CaptureProcessor.init()")
  local this = CaptureProcessor
  this.firstCapture = true
  this.lineCount=0
  this.debugHex=""

  this.dataText = ""

  form.clear()
  local line = form.addLine("")
  form.addLine(string.format("Capturing Data I2C=0x%02X",i2cID))
  form.addTextButton(nil, {x=LCD_W-80,y=5,w=75,h=LCD_LINE_H*1.2}, "Back", function() CaptureProcessor.close() end)
end

function CaptureProcessor.close()
  MainScreenProcessor.telPageSelected = 1  -- any page, return to Main
  MainScreenProcessor.init()
end

function CaptureProcessor.paint(I2C_ID)
  local this = CaptureProcessor
  local tw, th = lcd.sizeText("XXX")

  local x, y  = 0 , 0

  lcd.clear()
  form.draw()

  y = form.height() 
  x =  (LCD_W - lcd.sizeText("Line: ")) / 2 -- Centered
  lcd.drawText(x,y, string.format("Line : %d",this.lineCount),CENTER)

  y = y + th
  lcd.drawText(x,y, this.dataText, CENTER)
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
  local data = getFrameData(I2C_ID)

  if (data ~= nil) then   
      this.debugHex = ""
      this.debugHexForCode = ""

      for i=0,15 do
          local sep = (i==15 and "") or ","
          this.debugHexForCode= this.debugHexForCode .. string.format("0x%02X%s", (data[i] or 0xFF),sep)
          this.debugHex       = this.debugHex        .. string.format("%02X ", (data[i] or 0xFF))
      end

      this.lineCount=this.lineCount+1
      LOG_write("%s\n",this.debugHexForCode)

      this.lineText = string.format("Lines: %d",this.lineCount)
      this.dataText = this.debugHex

      --lcd.invalidate()
  end
end -- Wakeup

function CaptureProcessor.event(I2C_ID, evt, touchState)
  --print("CaptureProcessor.event() called")
  local this = CaptureProcessor

  local ret = form.event(evt,touchState)

  if (ret == 2) then
    CaptureProcessor.close()
  end
  return 0
end

---------------------------------------------------------------------------------------------

function MainScreenProcessor.init()
  local this = MainScreenProcessor
  this.telPageSelected = 1
  this.telPage = 2


  -- Dynamically Resize Buttons
  local buttonHeight = LCD_LINE_H * 2
  local buttonWidth = LCD_W / 4
  local buttonHeightPadding = LCD_LINE_H / 4
  local buttonWidthPadding = buttonWidth / 4

  form.clear()
  form.setWindowTitle("Capture")
  local line = form.addLine("Telemetry Raw Capture")
  form.addTextButton(nil, {x=LCD_W-80,y=5,w=75,h=LCD_LINE_H*1.2}, "Back", function() config.exit() end)

  local sectionHeight = form.height() + 10

  for iParam=2, #this.menu do    
    -- Convert X,Y 3x7 matrix
    local menuPos = iParam-2
    local menuCol =  menuPos % 3 
    local menuRow =  math.floor(menuPos / 3) 

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
  lcd.clear()
  form.draw()
end

function  MainScreenProcessor.event(I2C_ID, evt, touchState)
  --print("MainScreenProcessor.event() called")

  local this    =  MainScreenProcessor
  local ret     =  form.event(evt,touchState)

  return ret
end

---------------------------------------------------------------------------------------------

local function create()
  print("capture.create() called")
  
  --lcd.font(FONT_STD)

  --lcd.setWindowTitle("Telemery Capture")
  local tw,th = lcd.sizeText("X")

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

local function event(widget, evt, touchState)
  --print("Event received:", category, value, x, y)
  
  local m  =  MainScreenProcessor
  local Proc   = m.menu[m.telPageSelected][2]
  local params = m.menu[m.telPageSelected][3]

  if (Proc.event) then
    local ret = Proc.event(params, evt, touchState)
  end

  return 0
end

return {create=create, close=close, wakeup=wakeup, event=event, paint=paint}