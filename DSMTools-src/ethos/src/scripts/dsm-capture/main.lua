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
 

local translations = {en="DSM Capture 1.1"}

local SIMULATOR = false
--

local LCD_X_MAX,LCD_Y_MAX       = 400, 275
local LCD_Y_LINE_HEIGHT         = 20
local LCD_Y_HEADER              = 0
local LCD_Y_DATA                = LCD_Y_HEADER + LCD_Y_LINE_HEIGHT * 2 

local LCD_TEXT_COLOR         = lcd.themeColor(THEME_DEFAULT_COLOR)
local LCD_FOCUS_COLOR        = lcd.themeColor(THEME_FOCUS_COLOR)

local LOG_DIR  = "/logs"
local LOG_FILE = LOG_DIR .. "/dsm_raw_tel.txt"
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
    {"Main Menu ",             0,    MainScreenProcessor}, 
    {"Quality of Signal 0x7F", 0x7F, CaptureProcessor},
    {"TextGen (0x0C)",         0x0C, CaptureProcessor},
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
    if (multiSensor==nil) then
       multiSensor = multimodule.getSensor()
    end
end

local function closeTelemetryRaw()
    multiSensor = nil

end

local function getTelemetryFrame(I2C_ID)
    -- The inbound Frame has the following format starting at index 1:
    -- MultiModule Header: [1]=RSSI,[2]=Type,[3]=???, 
    -- Data: [4...19]= data for that frame, starting with I2C_ID

  if (SIMULATOR) then
    return { 0x7F, 0x00, 0x00, 0x00}
  end

  local data =  multiSensor:popFrame({i2cAddress=I2C_ID})
  --local data =  multiSensor:popFrame()

  if (data) then
    local i2cId = data[4] or 0
    if (I2C_ID > 0 and i2cId ~= I2C_ID) then   -- not the data we want?
      --data = nil
    end
  end

  return data
end

---------------------------------------------------------------------------------------------

function CaptureProcessor.init()
  local this = CaptureProcessor
  this.firstCapture = true
  this.lineCount=0
  this.debugHex=""
  this.haderHex=""
end

function CaptureProcessor.paint(I2C_ID)
  local this = CaptureProcessor
  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_STD)
  -- Header
  lcd.drawText (1,1,  "  Capturing Data.. Press RTN to end   ")
  lcd.drawText (1,LCD_Y_LINE_HEIGHT*2, string.format("Lines: %d",this.lineCount))
  -- 
  lcd.drawText (1,LCD_Y_DATA*4,this.headerHex)
  lcd.drawText (1,LCD_Y_DATA*5,this.debugHex)
end -- Paint

function CaptureProcessor.wakeup(I2C_ID)
  --print("CaptureProcessor.wakeup() called")
  local this = CaptureProcessor

  if (this.firstCapture) then -- First time run???
    this.firstCapture = false
    if (multiSensor==nil) then -- Could not open??
      LOG_write("ERROR, Cannot open MultiSensor Queue")
      system.error("Cannot open MultiSensor Queue");
    end
    LOG_close()
    LOG_open()
    LOG_write("--------- Capturing I2C_ID %2X\n",I2C_ID)
  end

  -- Proces Telementry message
  local data = getTelemetryFrame(I2C_ID)

  if (data ~= nil) then   
      this.debugHex = ""
      this.headerHex = ""

      for i=1,3 do
        this.headerHex=this.headerHex .. string.format(" %02X", (data[i] or 0xFF))
      end

      for i=4,19 do
          this.debugHex=this.debugHex .. string.format(" %02X", (data[i] or 0xFF))
      end

      this.lineCount=this.lineCount+1
      LOG_write("Header: %s Data: %s\n",this.headerHex, this.debugHex)
      lcd.invalidate()
  end
end -- Wakeup

function CaptureProcessor.event(I2C_ID, category, key)
  --print("CaptureProcessor.event() called")
  local this = CaptureProcessor

  if (key == KEY_RTN_BREAK) then
    MainScreenProcessor.telPageSelected = 1  -- any page, return to Main
    CaptureProcessor.init() 
    lcd.invalidate()
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
 
      lcd.color(LCD_TEXT_COLOR)
      lcd.font(FONT_BOLD)

      lcd.drawText (1, LCD_Y_HEADER, "Telemetry RAW Capture")

      for iParam=2, #this.menu do    
        lcd.color(LCD_TEXT_COLOR)
        lcd.font(FONT_STD)
      
        -- set y draw coord
        local y = (iParam-1)*LCD_Y_LINE_HEIGHT+LCD_Y_DATA 
        local x = 1

        if (iParam > 7) then
          x = LCD_X_MAX / 2
          y = (iParam-7)*LCD_Y_LINE_HEIGHT+LCD_Y_DATA 
        end

       
        -- highlight selected parameter
        if this.telPage==iParam then
          lcd.color(LCD_FOCUS_COLOR)
          lcd.font(FONT_BOLD)
        end

        local title = this.menu[iParam][1] -- Title
        lcd.drawText (x, y, title)
      end
end

function  MainScreenProcessor.event(I2C_ID, category, key)
  local this    =  MainScreenProcessor

  --print("MainScreenProcessor.event() called")
  if key == nil then return
  elseif key == KEY_ROTARY_LEFT then
    if (this.telPage>2) then this.telPage = this.telPage - 1 end
  elseif key == KEY_ROTARY_RIGHT then
    if (this.telPage < #this.menu) then this.telPage = this.telPage + 1 end
  elseif key == KEY_ENTER_BREAK then
    this.telPageSelected = this.telPage -- Activate current page
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
  MainScreenProcessor.init()
  CaptureProcessor.init()

  lcd.font(FONT_STD)
  LCD_X_MAX, LCD_Y_MAX = lcd.getWindowSize()
  local tw,th = lcd.getTextSize("")
  
  -- Recompute line positions
  LCD_Y_LINE_HEIGHT   = th + 1
  LCD_Y_DATA          = LCD_Y_HEADER + LCD_Y_LINE_HEIGHT 

  openTelemetryRaw() 

  os.mkdir(LOG_DIR)
  return {}
end

local function wakeup(widget)
  local m  =  MainScreenProcessor
  local I2C_ID = m.menu[m.telPageSelected][2]
  local Proc   = m.menu[m.telPageSelected][3]

  if (Proc.wakeup) then
    Proc.wakeup(I2C_ID)
  end
end

local function paint(widget)
  --print("paint() called")
  local m  =  MainScreenProcessor
  local I2C_ID = m.menu[m.telPageSelected][2]
  local Proc   = m.menu[m.telPageSelected][3]

  if (Proc.paint) then
    Proc.paint(I2C_ID)
  end
end

local function event(widget, category, value, x, y)
  --print("Event received:", category, value, x, y)
  if category == EVT_KEY then
    if (value == KEY_RTN_LONG) then  -- Exit??
      closeTelemetryRaw()
      LOG_close()
      system.exit()
    end

    local m  =  MainScreenProcessor
    local I2C_ID = m.menu[m.telPageSelected][2]
    local Proc   = m.menu[m.telPageSelected][3]
  
    if (Proc.event) then
      Proc.event(I2C_ID, category, value)
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