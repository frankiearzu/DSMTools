local toolName = "TNS|DSM Telemetry Capture |TNE"
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
local X_COL1_HEADER         = 6
local X_COL1_DATA           = 60
local X_COL2_HEADER         = 170
local X_COL2_DATA           = 220
local Y_LINE_HEIGHT         = 20
local Y_HEADER              = 0
local Y_DATA                = Y_HEADER + Y_LINE_HEIGHT*2 
local X_DATA_LEN            = 80 
local X_DATA_SPACE          = 5

local LOG_FILE = "/LOGS/dsm_raw_tel.txt"
local logFile = nil 
local logCount = 0


local function LOG_open()  
    logFile = io.open(LOG_FILE, "a")  -- Truncate Log File 
end

local function LOG_write(...)
    if (logFile==nil) then LOG_open() end
    local str = string.format(...)
    io.write(logFile, str)

    print(str)

    if (logCount > 10) then  -- Close an re-open the file
        io.close(logFile)
        logFile = io.open(LOG_FILE, "a")
        logCount =0
    end
end

local function LOG_close()
    if (logFile~=nil) then io.close(logFile) end
end


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


local lineCount=0
local debugHex=""

local function log_I2C_Data(event, I2C_ID)
 
  if (multiBuffer(0)~=string.byte('S')) then -- First time run???
    lineCount=0
    debugHex=""
    openTelemetryRaw(I2C_ID) -- I2C_ID for TEXT_GEN
    LOG_close()
    LOG_open()
    LOG_write("--------- Capturing I2C_ID %2X\n",I2C_ID)
  end

  -- Proces TEXT GEN Telementry message
  if multiBuffer( 4 ) == I2C_ID then -- Specktrum Telemetry ID of data received
    local instanceNo = multiBuffer( 5 )
    debugHex = string.format("%02X %02X",I2C_ID,instanceNo)
    for i=0,15 do
        debugHex=debugHex .. string.format(" %02X", multiBuffer( 6 + i ))
    end

    multiBuffer( 4, 0 ) -- Clear Semaphore, to notify that we fully process the current message
    lineCount=lineCount+1
    LOG_write("%s\n",debugHex)
  end

  lcd.clear()
  -- Header
  lcd.drawText (X_COL1_HEADER,0,  "  Capturing Data.. Press RTN to end   ", TEXT_SIZE)
  lcd.drawText (X_COL1_HEADER,Y_LINE_HEIGHT, string.format("Lines: %d",lineCount), TEXT_SIZE)
  -- 
  lcd.drawText (X_COL1_HEADER,Y_DATA*2,debugHex, TEXT_SIZE)
  

  if event == EVT_VIRTUAL_EXIT then -- Exit?? Clear menu data
    closeTelemetryRaw()
    LOG_close()
  end
end

local function capture16(event)
    log_I2C_Data(event,0x16)
end

local function capture17(event)
    log_I2C_Data(event,0x16)
end

local function capture26(event)
    log_I2C_Data(event,0x26)
end

local function capture7F(event)
    log_I2C_Data(event,0x7F)
end

---------------------------------------------------------------------------------------------
local telPage = 1
local telPageSelected = 0
local pageTitle = {[0]="Main", "GPS_LOC (0x16)", "GPS_STAT(0x17)","GPS_BIN (0x26)","Qual of Signal QoS (0x7F)"}

local function drawMainScreen(event) 
  lcd.clear()
  lcd.drawText (X_COL1_HEADER, Y_HEADER, "Telemetry RAW Capture", TEXT_SIZE + INVERS)

  for iParam=1,#pageTitle do    
    -- highlight selected parameter
    local attr = (telPage==iParam) and INVERS or 0

    -- set y draw coord
    local y = (iParam)*Y_LINE_HEIGHT+Y_DATA 
    
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


local pageDraw  = {[0]=drawMainScreen, capture16, capture17, capture26, capture7F}

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
    X_COL1_HEADER         = 0
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
