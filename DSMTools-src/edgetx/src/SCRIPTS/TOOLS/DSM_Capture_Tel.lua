local toolName = "TNS|DSM Capture 1.1 |TNE"
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
 

local DEBUG_ON = false
--

local TEXT_SIZE             = 0 -- NORMAL
local LCD_COL1              = 6
local LCD_Y_LINE_HEIGHT     = 20
local LCD_Y_HEADER          = 0
local LCD_Y_DATA            = 0 -- First Line of data. Calculated during init


local LOG_DIR  = "/logs"
local LOG_FILE = LOG_DIR .. "/dsm_raw_tel.txt"
local logFile = nil 

local CaptureProcessor = {
  firstCapture = true,
  lineCount=0,
  debugHex="",
}

local MainScreenProcessor = {
  telPage = 0,             -- Current Menu Pos
  telPageSelected = 0,     -- Active Page  
}

MainScreenProcessor.menu = {
    {"Main Menu ",             0,    MainScreenProcessor}, 
    {"Quality of Signal 0x7F", 0x7F, CaptureProcessor},
    {"RPM/Volts (0x7E)",       0x7E, CaptureProcessor},
    {"Flight Pack (0x34)",     0x34, CaptureProcessor},
    {"Flight-Ctlr (0x05)",     0x05, CaptureProcessor},
    {"ESC (0x20)",             0x20, CaptureProcessor},
    {"Vario (0x40)",           0x40, CaptureProcessor},
    {"PowerBox (0x0A)",        0x0A, CaptureProcessor},
    {"SkyID (0x27)",           0x27, CaptureProcessor},
    {"GPS-Loc (0x16)",         0x16, CaptureProcessor},
    {"GPS-Stat (0x17)",        0x17, CaptureProcessor},
    {"GPS-Bin (0x26)",         0x26, CaptureProcessor}
}

---------------------------------------------------------------------------------------------

local function LOG_open()  
    logFile = assert(io.open(LOG_FILE, "a"))  -- Truncate Log File 
end

local function LOG_write(...)
    if (logFile==nil) then LOG_open() end
    local str = string.format(...)
    io.write(logFile, str)

    print(str)
end

local function LOG_close()
    if (logFile~=nil) then io.close(logFile) end
end

---------------------------------------------------------------------------------------------

local function openTelemetryRaw(i2cId)
    --Init telemetry  (Spectrun Telemetry Raw STR)
    multiBuffer( 0, string.byte('S') )
    multiBuffer( 1, string.byte('T') )
    multiBuffer( 2, string.byte('R') ) 
    multiBuffer( 3, i2cId ) -- Monitor this telemetry data
    multiBuffer( 4, 0 ) -- Allow to get Data
end

local function closeTelemetryRaw()
    multiBuffer(0, 0) -- Destroy the STR header 
    multiBuffer(3, 0) -- Not requesting any Telementry ID
end

local function getTelemetryFrame(I2C_ID)
  local data = nil
  if multiBuffer( 4 ) == I2C_ID then -- Specktrum Telemetry ID of data received
    local instanceNo = multiBuffer( 5 )
    data = {I2C_ID,instanceNo}
    for i=0,15 do
        data[i+3]=multiBuffer( 6 + i )
    end
    multiBuffer( 4, 0 ) -- Clear Semaphore, to notify that we fully process the current message
  end
  return data
end

---------------------------------------------------------------------------------------------

function CaptureProcessor.init()
  local this = CaptureProcessor
  this.firstCapture = true
  this.lineCount=0
  this.debugHex=""
end

function CaptureProcessor.paint(I2C_ID)
  local this = CaptureProcessor
  lcd.clear()
  -- Header
  lcd.drawText (LCD_COL1,0,  "  Capturing Data.. Press RTN to end   ", TEXT_SIZE)
  lcd.drawText (LCD_COL1,LCD_Y_LINE_HEIGHT*2, string.format("Lines: %d", this.lineCount), TEXT_SIZE)
  -- 
  lcd.drawText (LCD_COL1,LCD_Y_DATA*4,this.debugHex, TEXT_SIZE)
end -- Paint

function CaptureProcessor.wakeup(I2C_ID)
  --print("CaptureProcessor.wakeup() called")
  local this = CaptureProcessor

  if (this.firstCapture) then -- First time run???
    this.firstCapture = false
    openTelemetryRaw(I2C_ID)
    LOG_close()
    LOG_open()
    LOG_write("--------- Capturing I2C_ID %2X\n",I2C_ID)
  end

  -- Proces Telementry message
  local data = getTelemetryFrame(I2C_ID)

  if (data ~= nil) then   
      this.debugHex = ""
      for i=1,15 do
          this.debugHex=this.debugHex .. string.format(" %02X", (data[i] or 0))
      end

      this.lineCount=this.lineCount+1
      LOG_write("%s\n",this.debugHex)
  end
end -- Wakeup


function CaptureProcessor.event(I2C_ID, key)
  --print("CaptureProcessor.event() called")
  local this = CaptureProcessor

  if (key == EVT_VIRTUAL_EXIT) then
    MainScreenProcessor.telPageSelected = 1  -- any page, return to Main
    CaptureProcessor.init() 
    closeTelemetryRaw()
    LOG_close()
  end
end

---------------------------------------------------------------------------------------------

function MainScreenProcessor.init()
  local this = MainScreenProcessor
  this.telPageSelected = 1
  this.telPage = 2
end

function MainScreenProcessor.paint(I2C_ID)
      local this    =  MainScreenProcessor
 
      lcd.clear()
      lcd.drawText (LCD_COL1, LCD_Y_HEADER, "Telemetry Capture 1.1", TEXT_SIZE + INVERS)

      for iParam=2, #this.menu do    
        -- set y draw coord
        local y = (iParam-1)*LCD_Y_LINE_HEIGHT+LCD_Y_DATA 
        local x = 1

        if (iParam > 7) then
          x = LCD_W / 2
          y = (iParam-7) * LCD_Y_LINE_HEIGHT+LCD_Y_DATA 
        end

        -- highlight selected parameter
        local attr = (this.telPage==iParam) and INVERS or 0

        local title = this.menu[iParam][1] -- Title
        lcd.drawText (x, y, title, attr + TEXT_SIZE)
      end
end

function  MainScreenProcessor.event(I2C_ID, key)
  local this    =  MainScreenProcessor

  --print("MainScreenProcessor.event() called")
  if key == nil then return
  elseif key == EVT_VIRTUAL_PREV then
    if (this.telPage>2) then this.telPage = this.telPage - 1 end
  elseif key == EVT_VIRTUAL_NEXT then
    if (this.telPage < #this.menu) then this.telPage = this.telPage + 1 end
  elseif key == EVT_VIRTUAL_ENTER then
    this.telPageSelected = this.telPage -- Activate current page
  end
end


local function init()
  MainScreenProcessor.init()

  if (LCD_W <= 128 or LCD_H <=64) then -- Smaller Screens 
    TEXT_SIZE         = SMLSIZE -- Small Font
    LCD_COL1          = 0
    --LCD_Y_LINE_HEIGHT = 8
  else
    TEXT_SIZE             = 0 -- Normal Font 
    LCD_COL1              = 6
    --LCD_Y_LINE_HEIGHT     = 20
  end

  local tw, th = lcd.sizeText("", TEXT_SIZE)
  
  -- Recompute line positions
  LCD_Y_LINE_HEIGHT   = th + 1
  LCD_Y_DATA          = LCD_Y_HEADER + LCD_Y_LINE_HEIGHT 
end


local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  local m  =  MainScreenProcessor
  local I2C_ID = m.menu[m.telPageSelected][2] -- ID
  local Proc   = m.menu[m.telPageSelected][3] -- Processor

  -- draw specific page 
  if (Proc.paint) then
    Proc.paint(I2C_ID)
  end

  if (Proc.wakeup) then
    Proc.wakeup(I2C_ID)
  end

  if event == EVT_VIRTUAL_EXIT then
    if (m.telPageSelected==1) then -- on Main?? Exit Script
      closeTelemetryRaw()
      LOG_close()
      return 1 
    end   
  end

  if (Proc.event) then
    Proc.event(I2C_ID, event)
  end

  return 0
end



return { run=run,  init=init  }
