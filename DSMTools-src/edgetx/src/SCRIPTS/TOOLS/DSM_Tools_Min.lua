local toolName = "TNS|DSMTools 2.4 (min)|TNE"
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

-- Change the paths as needed.. the local directory is where the TOOLS are.

local DSM_PATH              = "./dsm-tools-min/"                 -- Directory/Folder where the DSM scripts are

local TEXT_SIZE             = 0 -- NORMAL
local LCD_COL1              = 6
local LCD_Y_LINE_HEIGHT     = 20
local LCD_Y_HEADER          = 0
local LCD_Y_DATA            = 0 -- First Line of data. Calculated during init

local runningLua            = nil

local MainScreen = {
  menuPos = 2             -- Current Menu Pos
}

MainScreen.menu = {
    {"Plane Setup",                DSM_PATH.."apps/app-setup-min.lua"},
    {"Forward Prog",               DSM_PATH.."apps/app-fp-min.lua"},
    {"Telemetry",                  DSM_PATH.."apps/app-tel-min.lua"},
}

---------------------------------------------------------------------------------------------

function MainScreen.init()
  local this = MainScreen
  this.menuPos = 2
end

function MainScreen.paint()
      local this    =  MainScreen
 
      lcd.clear()
      lcd.drawText (LCD_COL1, LCD_Y_HEADER, "   DsmTools Suite", TEXT_SIZE +  BOLD) -- Title
      lcd.drawText (LCD_COL1, LCD_H - LCD_Y_LINE_HEIGHT, "      v2.4  arzu/langer", TEXT_SIZE +  BOLD) -- Title

      for iParam=1, #this.menu do    
        -- set y draw coord
        local y = (iParam-0)*LCD_Y_LINE_HEIGHT + LCD_Y_DATA 
        local x = LCD_COL1

        -- highlight selected parameter
        local attr = (this.menuPos==iParam) and INVERS or 0

        local title = this.menu[iParam][1] -- Title
        lcd.drawText (x, y, title, attr + TEXT_SIZE)
      end
end

function  MainScreen.event(key)
  local this    =  MainScreen

  --print("MainScreenProcessor.event() called")
  if key == nil then return
  elseif key == EVT_VIRTUAL_PREV then
    if (this.menuPos>1) then this.menuPos = this.menuPos - 1 end
  elseif key == EVT_VIRTUAL_NEXT then
    if (this.menuPos < #this.menu) then this.menuPos = this.menuPos + 1 end
  elseif key == EVT_VIRTUAL_ENTER then
    -- Execute external LUA
    local luaName = this.menu[this.menuPos][2]
    local r = assert(loadScript(luaName), "Mising:"..luaName)
    runningLua = r()
    runningLua.init()
  end
end


local function init()
  MainScreen.init()
  local th = 10

  if (LCD_H <=64) then -- Smaller Screens 
    TEXT_SIZE         = SMLSIZE -- Small Font
    LCD_COL1          = 0
    LCD_Y_LINE_HEIGHT = 9 
  else
    TEXT_SIZE         = 0 -- Normal Font 
    LCD_COL1          = 6
    LCD_Y_LINE_HEIGHT = 25
  end

  -- Recompute line positions
  LCD_Y_DATA          = LCD_Y_HEADER + LCD_Y_LINE_HEIGHT 
end


local function run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  if (runningLua) then
    local r = runningLua.run(event)
    if (r > 0) then
        -- Exit SubProgram
        runningLua = nil
    end
    return 0
  else
    MainScreen.paint()
    MainScreen.event(event)
    if event == EVT_VIRTUAL_EXIT then
        return 1 
    end
  end

  return 0
end

return { run=run,  init=init  }
