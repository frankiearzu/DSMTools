---- #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
-----#                                                                       #
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


local VERSION             = "v0.59"
local LANGUAGE            = "en"
local DSMLIB_PATH         = "/scripts/dsm-fwdprog/"
local DEBUG_ON            = 1
local SIMULATOR           = false

local I2C_FORWARD_PROG    = 0x09

local LOG_PATH            ="/logs"
local LOG_FILE            = LOG_PATH .. "/dsm_log.txt"
local MSG_FILE            = "msg_fwdp_" .. LANGUAGE .. ".txt"
local IMG_PATH            = "img/"

-- Phase
local PH_INIT = 0
local PH_RX_VER, PH_TITLE, PH_TX_INFO, PH_LINES, PH_VALUES = 1, 2, 3, 4, 5
local PH_VAL_CHANGING, PH_VAL_EDITING, PH_VAL_EDIT_END     = 6, 7, 8
local PH_WAIT_CMD, PH_EXIT_REQ, PH_EXIT_DONE               = 9, 10, 11

-- Line Types
local LT_MENU             = 0x1C 
local LT_LIST_NC, LT_LIST_NC2, LT_LIST, LT_LIST_ORI, LT_LIST_TOG = 0x6C, 0x6D, 0x0C, 0xCC, 0x4C
local LT_VALUE_NC = 0x60
local LT_VALUE_PERCENT, LT_VALUE_DEGREES, LT_VALUE_PREC2 = 0xC0, 0xE0, 0x69

local Phase               = PH_INIT
local SendDataToRX        = 1   -- Initiate Sending Data

local Text                = {}
local List_Text           = {}
local List_Text_Img       = {}
local Flight_Mode         = {[0]="Fligh Mode %s", "Flight Mode %s", "Gyro System %s / Flight Mode %s"}
local RxName              = {}

local TXInactivityTime    = 0.0
local RXInactivityTime    = 0.0
local TX_Info_Step        = 0
local TX_Info_Type        = 0
local Change_Step         = 0
local originalValue       = 0
local multiSensor         = 0

local TX_CHANNELS         = 12
local TX_MAX_CH           = TX_CHANNELS - 6 -- Number of Channels after Ch6
local TX_FIRMWARE_VER     = 0x15

--local ctx = {
local  ctx_SelLine = 0      -- Current Selected Line
local  ctx_EditLine = nil   -- Current Editing Line
local  ctx_CurLine = -1     -- Current Line Requested/Parsed via h message protocol
local  ctx_isReset = false   -- false when starting from scracts, true when starting from Reset
--}

local Menu                = { MenuId = 0, Text = "", TextId = 0, PrevId = 0, NextId = 0, BackId = 0 }
local MenuLines           = {}
local RX_Name             = ""
local RX_Version          = ""

local logFile             = nil

--local LCD_X_LINE_TITLE    = 0
--local LCD_X_LINE_VALUE    = 75

local LCD_W_BUTTONS       = 60
local LCD_H_BUTTONS       = 20

local LCD_X_MAX,LCD_Y_MAX   = 400, 275
local LCD_X_RIGHT_BUTTONS   = LCD_X_MAX - LCD_W_BUTTONS - 1

local LCD_Y_LINE_HEIGHT   = 7
local LCD_Y_LOWER_BUTTONS = (8 * LCD_Y_LINE_HEIGHT) + 2

local LCD_TEXT_COLOR        = lcd.themeColor(THEME_DEFAULT_COLOR)
local LCD_TEXT_BGCOLOR      = lcd.themeColor(THEME_DEFAULT_BGCOLOR)

local LCD_FOCUS_COLOR        = lcd.themeColor(THEME_FOCUS_COLOR)
local LCD_FOCUS_BGCOLOR      = lcd.themeColor(THEME_FOCUS_BGCOLOR)

local LCD_HEADER_COLOR       = lcd.themeColor(THEME_DEFAULT_COLOR)
local LCD_HEADEER_BGCOLOR    = lcd.themeColor(THEME_DEFAULT_BGCOLOR)

--Channel Types --
local CT_NONE     = 0x00
local CT_AIL      = 0x01
local CT_ELE      = 0x02
local CT_RUD      = 0x04
local CT_REVERSE  = 0x20
local CT_THR      = 0x40
local CT_SLAVE    = 0x80

-- Seems like Reverse Mix is complement of the 3 bits
local CMT_NORM     = 0x00   -- 0000
local CMT_AIL      = 0x10   -- 0001 Taileron
local CMT_ELE      = 0x20   -- 0010 For VTIAL and Delta-ELEVON
local CMT_RUD      = 0x30   -- 0011 For VTIAL
local CMT_RUD_REV  = 0x40   -- 0100 For VTIAL
local CMT_ELE_REV  = 0x50   -- 0101 For VTIAL and Delta-ELEVON A
local CMT_AIL_REV  = 0x60   -- 0110 Taileron 
local CMT_NORM_REV = 0x70    -- 0111

local MT_NORMAL      = 0
local MT_REVERSE     = 1

local MODEL = {
  modelName = "",            -- The name of the model comming from OTX/ETX
  modelOutputChannel = {},   -- Output information from OTX/ETX

  TX_CH_TEXT= { }, 
  PORT_TEXT = { },

  DSM_ChannelInfo = { [0] =
       {[0]= CMT_NORM, CT_THR, "Ch1"},
       {[0]= CMT_NORM, CT_AIL, "Ch2"},
       {[0]= CMT_NORM, CT_ELE, "Ch3"},
       {[0]= CMT_NORM, CT_RUD, "Ch4"},
       {[0]= CMT_NORM, CT_NONE, "Ch5"},
       {[0]= CMT_NORM, CT_NONE, "Ch6"},
       {[0]= CMT_NORM, CT_NONE, "Ch7"},
       {[0]= CMT_NORM, CT_NONE, "Ch8"},
       {[0]= CMT_NORM, CT_NONE, "Ch9"},
       {[0]= CMT_NORM, CT_NONE, "Ch10"},
       {[0]= CMT_NORM, CT_NONE, "Ch11"},
       {[0]= CMT_NORM, CT_NONE, "Ch12"}
  }
}



local M_DATA = {}

local WT_A1       = 0
local WT_A2       = 1
local WT_FLPR     = 2
local WT_A1_F1    = 3
local WT_A2_F1    = 4
local WT_A2_F2    = 5
local WT_ELEVON_A = 6
local WT_ELEVON_B = 7


local TT_R1    = 0
local TT_R1_E1 = 1
local TT_R1_E2 = 2
local TT_R2_E1 = 3
local TT_R2_E2 = 4
local TT_VT_A  = 5
local TT_VT_B  = 6
local TT_TLRN_A = 7
local TT_TLRN_B = 8
local TT_TLRN_A_R2 = 9
local TT_TLRN_B_R2 = 10

local MV_AIRCRAFT_TYPE = 1001
local MV_WING_TYPE     = 1002
local MV_TAIL_TYPE     = 1003
        
local MV_CH_BASE       = 1010
local MV_CH_THR        = 1010
local MV_CH_L_AIL      = 1011
local MV_CH_R_AIL      = 1012
local MV_CH_L_FLP      = 1013
local MV_CH_R_FLP      = 1014

local MV_CH_L_RUD      = 1015
local MV_CH_R_RUD      = 1016
local MV_CH_L_ELE      = 1017
local MV_CH_R_ELE      = 1018

local MV_PORT_BASE       = 1020


local startTime         = os.clock()

--------------------------------------------------------------------------------------------------
local _multiBuffer     = {[0]=0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local function multiBuffer(addr,data)
  if (data==nil) then
    -- read
    return _multiBuffer[addr] or 0
  else
    _multiBuffer[addr] = data
    return data
  end
end

local function getTime()
  return os.clock() 
end
---------------------------------------------------------------------------------------------------

local function gc()
  collectgarbage("collect")
end

local function LOG_open()
  if (DEBUG_ON == 0) then return end
  logFile = assert(io.open(LOG_FILE, "w"))   -- Truncate Log File
end

local function LOG_write(...)
  if (DEBUG_ON == 0) then return end
  if (logFile == nil) then LOG_open() end
  local str = string.format("%s :",(os.clock()-startTime)) .. string.format(...)
  io.write(logFile, str)
  print(str)
end

local function LOG_close()
  if (logFile ~= nil) then io.close(logFile); logFile = nil end
end

----- Line Type
local function isIncrementalValueUpdate(line)
  if (line.Type == LT_LIST_NC or line.Type == LT_LIST_NC2 or 
      line.Type == LT_VALUE_NC or line.Type == LT_VALUE_DEGREES) then return false end
  return true
end

local function isSelectable(line)
  if (line.TextId == 0x00CD) then return true end                          -- Exceptiom: Level model and capture attitude
  if (line.Type == LT_MENU and line.ValId == line.MenuId) then return false end -- Menu to same page
  if (line.Type ~= LT_MENU and  line.Max == 0 and line.Min == 0) then return false end            -- Read only data line 
  if (line.TextId > 0 and line.TextId < 0x8000) then return true end          -- Not Flight Mode
  return false;
end

local function isListLine(line) 
  return line.Type==LT_LIST_NC or line.Type==LT_LIST_NC2 or 
         line.Type == LT_LIST or line.Type == LT_LIST_ORI or line.Type == LT_LIST_TOG
end

local function isEditing() 
  return  ctx_EditLine ~= nil
end


---------------- DSM Values <-> Int16 Manipulation --------------------------------------------------------

local function int16_LSB(number) -- Less Significat byte
  local r = number & 0xFF
  return r
end

local function int16_MSB(number) -- Most signifcant byte
  return number >> 8
end

local function Dsm_to_Int16(lsb, msb) -- Componse an Int16 value
  return (msb << 8) | lsb
end

local function Dsm_to_SInt16(lsb, msb) -- Componse a SIGNED Int16 value
  local value = (msb << 8) + lsb
  if value >= 0x8000 then             -- Negative value??
    return value - 0x10000
  end
  return value
end

local function sInt16ToDsm(value) -- Convent to SIGNED DSM Value
  if value < 0 then
    value = 0x10000 + value
  end
  return value
end

-----------------------
local function rtrim(s)
  local n = string.len(s)
  while n > 0 and string.find(s, "^%s", n) do n = n - 1 end
  return string.sub(s, 1, n)
end

local function GetTextInfoFromFile(pos)
  -- open and read File
  local dataFile = assert(io.open(MSG_FILE, "r"))  
  dataFile:seek(pos)
  local buff = dataFile:read("*line")
  io.close(dataFile)

  local line=""
  local index=""
  local type=""

  -- EOF??
  if (buff==nil) then return type, index, rtrim(line), pos end

  local pipe=0
  local comment=0
  local specialCh=0
  local newPos = pos

  -- Parse the line: 
  -- Format:  TT|0x999|Text -- Comment

  for i=1,#buff do
    newPos=newPos+1
    local ch = string.sub(buff,i,i)

    if (pipe < 2 and ch=="|") then pipe=pipe+1 -- Count pipes pos  (Type | Index | .....)
    elseif (specialCh==1) then -- Skip special characters
      specialCh=0
      if (ch=="c" or ch=="b" or ch=="m" or ch=="r") then pipe=6 else line=line..'/'..ch end
    elseif (pipe == 2 and ch=="/") then specialCh=1
    elseif (ch=="\r") then -- Ignore CR
    elseif (ch=="\n") then break -- LF, end of line
    elseif (ch=="-") then  -- March comments
      comment=comment+1
      if (comment==2) then pipe=6 end -- Comment part of line
    else
      -- regular char
      comment=0
      if (pipe==0) then type=type..ch  -- in TT (Type)
      elseif (pipe==1) then index=index..ch  -- in Index
      elseif (pipe<6) then line=line..ch end -- in Text
    end -- Regular char 
  end -- Fpr
  if (comment==1) then line=line.."-" end -- End with a -, not a comment

  if (newPos > pos) then
    newPos = newPos + 1
  end

  return type, index, rtrim(line), newPos 
end

local function GetTextFromFile(pos)
  if (pos==nil) then return nil end
  local t,i,l, p = GetTextInfoFromFile(pos)
  return l
end

local  function getTxChText(index)
  local ch = nil
  local out = nil

  if (index >= 0x000D and index <= 0x000D+7) then ch = index - 0x000D + 5 -- ch5
  elseif (index >= 0x0036 and index <= 0x0036+11) then ch = index - 0x0036 end

  if (ch ~= nil) then
    out = "Ch"..(ch+1) .. " ("..(MODEL.TX_CH_TEXT[ch] or "--")..")"
    --out = MODEL.PORT_TEXT[ch] or "--"
  end 

  return out
end

-----------------------
local function Get_Text(index)
  local pos = Text[index]
  local out = nil

  if (pos == nil) then
    out = string.format("Unknown_%X", index) 
  else
    out = GetTextFromFile(pos)
  end

  if (index >= 0x5000) then
    out = ""
  end 

  if (index >= 0x8000) then
    out = Flight_Mode [index - 0x8000]
  end 

  return out
end

local function Get_Text_Value(index)
  local out = getTxChText(index)
  if (out) then return out end

  local pos = List_Text[index]
  if (pos == nil) then
    out = Get_Text(index)
  else
    out = GetTextFromFile(pos)
  end

  return out
end
---------------------
local function Get_RxName(index)
  local out = RxName[index] or string.format("Unknown_%X", index) 
  return out
end
--------------------

local function updateValText(line)
  line.ValText = line.Val
  if (isListLine(line)) then
    line.ValText = Get_Text_Value(line.TextStart + line.Val)
  end 
  if (line.Type == LT_VALUE_PREC2) then
    line.ValText = line.Val / 100
  end
end

local function DSM_Connect()
  
  
  if (not SIMULATOR) then
    multiSensor = multimodule.getSensor()
    --Init RX buffer
    multiBuffer(10, 0x00)
  end
end

local function DSM_Release()
  multiSensor = nil
  gc()
end
--------------------
local function DSM_Send(...)
  local arg = { ... }
  local out = { 0x70 + #arg } -- Header with the length + 0x70

  local hex = string.format("%02X ",out[1])
  local len = #arg
  if (len < 6) then len = 6 end

  for i = 1, len do
      hex = hex .. string.format("%02X ",arg[i] or 0)
      out[i+1] = arg[i] or 0
  end

  LOG_write("TX:Sending (hex)  %s\n",hex)

  multiSensor:pushFrame(out)
end
---------------------

function ChangePhase(newPhase)
  Phase = newPhase
  SendDataToRX = 1
end

local function Value_Add(dir)
  local line = MenuLines[ctx_SelLine]
  local origVal = line.Val
  local inc = dir

  if (not isListLine(line)) then -- List do slow inc 
    --[[
    local Speed = getRotEncSpeed()
    if Speed == ROTENC_MIDSPEED then
      inc = (5 * dir)
    elseif Speed == ROTENC_HIGHSPEED then
      inc = (15 * dir)
    end
    ]]--
  end

  line.Val = line.Val + inc

  if line.Val > line.Max then
    line.Val = line.Max
  elseif line.Val < line.Min then
    line.Val = line.Min
  end

  if (origVal~=line.Val) then -- Any changes?
    if (isIncrementalValueUpdate(line)) then
      -- Update RX value on every change, otherwise, just at the end 
      ChangePhase(PH_VAL_CHANGING)
    end 
    updateValText(line)
  end
end
--------------

local function GotoMenu(menuId, lastSelectedLine)
  Menu.MenuId = menuId
  ctx_SelLine = lastSelectedLine
  -- Request to load the menu Again
  ChangePhase(PH_TITLE)
end

local function DSM_HandleEvent(event)
  if event == KEY_RTN_LONG then
    Phase = PH_EXIT_DONE -- Exit program
    return 
  end

  if event == KEY_RTN_BREAK then
    if Phase == PH_RX_VER then
      Phase = PH_EXIT_DONE -- Exit program
    else
      if isEditing() then   -- Editing a Line, need to  restore original value
        MenuLines[ctx_EditLine].Val = originalValue
        event = KEY_ENTER_BREAK
      else
        if (Menu.BackId > 0 ) then -- Back??
          ctx_SelLine = -1 --Back Button
          event = KEY_ENTER_BREAK
        else
          ChangePhase(PH_EXIT_REQ)
        end
      end
    end
  end -- Exit

  if Phase == PH_RX_VER then return end -- nothing else to do 

  if event == KEY_ROTARY_RIGHT then  -- NEXT
    if isEditing() then -- Editting?
      Value_Add(1)
    else
      if ctx_SelLine < 7 then -- On a regular line
        local num = ctx_SelLine -- Find the prev selectable 
        for i = ctx_SelLine + 1, 6, 1 do
          local line = MenuLines[i]
          if isSelectable(line) then
            ctx_SelLine = i
            break
          end
        end
        if num == ctx_SelLine then       -- No Selectable Line
          if Menu.NextId ~= 0 then
            ctx_SelLine = 7 -- Next 
          elseif Menu.PrevId ~= 0 then
            ctx_SelLine = 8 -- Prev
          end
        end
      elseif Menu.PrevId ~= 0 then
        ctx_SelLine = 8 -- Prev
      end
    end
    return
  end
  
  if event == KEY_ROTARY_LEFT then -- PREV
    if isEditing() then -- In Edit Mode
      Value_Add(-1)
    else
      if ctx_SelLine == 8 and Menu.NextId ~= 0 then
        ctx_SelLine = 7 -- Next 
      elseif ctx_SelLine > 0 then
        if ctx_SelLine > 6 then
          ctx_SelLine = 7 --NEXT 
        end
        local num = ctx_SelLine -- Find Prev Selectable line
        for i = ctx_SelLine - 1, 0, -1 do
          local line = MenuLines[i]
          if isSelectable(line) then
            ctx_SelLine = i
            break
          end
        end
        if num == ctx_SelLine then   -- No Selectable Line
          if (Menu.BackId > 0) then 
            ctx_SelLine = -1 -- Back 
          end
        end
      else
        ctx_SelLine = -1   -- Back
      end
    end
    return
  end
  
  if event == EVT_VIRTUAL_ENTER_LONG then
    if isEditing() then
      MenuLines[ctx_SelLine].Val = MenuLines[ctx_SelLine].Def
      ChangePhase(PH_VAL_CHANGING)
    end
  elseif event == KEY_ENTER_BREAK then -- ENTER
    if ctx_SelLine == -1 then    -- Back
      GotoMenu(Menu.BackId, 0x80)
    elseif ctx_SelLine == 7 then -- Next
      GotoMenu(Menu.NextId, 0x82)
    elseif ctx_SelLine == 8 then -- Prev
      GotoMenu(Menu.PrevId, 0x81)
    elseif ctx_SelLine >= 0 and MenuLines[ctx_SelLine].Type == LT_MENU then
      GotoMenu(MenuLines[ctx_SelLine].ValId, ctx_SelLine)  -- ValId is the next menu
    else
      -- value entry
      if isEditing() then
        ctx_EditLine = nil   -- Done Editting
        ChangePhase(PH_VAL_EDIT_END)
      else   -- Start Editing
        ctx_EditLine = ctx_SelLine
        originalValue = MenuLines[ctx_SelLine].Val
        ChangePhase(PH_VAL_EDITING)
      end
    end
  end
end
------------------------------------------------------------------------------------------------------------

local function SendTxInfo(portNo)
  -- TxInfo_Type=0    : AR636 Main Menu (Send port/Channel info + SubTrim + Travel)
  -- TxInfo_Type=1    : AR630-637 Famly Main Menu  (Only Send Port/Channel usage Msg 0x20)
  -- TxInfo_Type=1F   : AR630-637 Initial Setup/Relearn Servo Settings (Send port/Channel info + SubTrim + Travel +0x24/Unknown)


  if (TX_Info_Step == 0) then  
      -- AR630 family: Both TxInfo_Type (ManinMenu=0x1,   Other First Time Configuration = 0x1F)
      local info = MODEL.DSM_ChannelInfo[portNo]
      local b0, b1, b2 = info[0], info[1], info[2]
      DSM_Send(0x20, 0x06, portNo, portNo, b0,b1)
      LOG_write("TX:DSM_TxInfo_20(Port=#%d, (%02x, %02x) %s)\n", portNo, b0,b1,b2 or "")

      if (TX_Info_Type == 0x1F) then -- SmartRx
          TX_Info_Step = 1
      elseif (TX_Info_Type == 0x00) then -- AR636
          TX_Info_Step = 2
      end 
  elseif (TX_Info_Step == 1) then
    local info = MODEL.modelOutputChannel[portNo]
    local leftTravel =   math.abs(math.floor(info.min/10))
    local rightTravel =  math.abs(math.floor(info.max/10))

    DSM_Send(0x23, 0x06, 0x00, leftTravel, 0x00, rightTravel)
    LOG_write("TX:DSM_TxInfo_Travel(Port=#%d,(L=%d - R=%d))\n", portNo,leftTravel,rightTravel)

    TX_Info_Step = 2
  elseif (TX_Info_Step == 2) then
    -- Subtrim 
    local b1,b2,b3,b4 = 0x00, 0x8E, 0x07, 0x72 -- (192-1904)
  
    local info = MODEL.DSM_ChannelInfo[portNo]
    if info[1] == 0x40 or info[1] == 0x00 then -- Thr and other switches
      b1,b2,b3,b4 = 0x00, 0x00, 0x07, 0xFF -- (0-2047)      
    end

    DSM_Send(0x21, 0x06, b1,b2,b3,b4) -- Port is not send anywhere, since the previous 0x20 type message have it.
    LOG_write("TX:DSM_TxInfo_SubTrim(Port=#%d)\n", portNo)

    if (TX_Info_Type == 0x00) then -- AR636
        TX_Info_Step = 5 -- End Step 
    else 
        TX_Info_Step = 3
    end
  elseif (TX_Info_Step == 3) then
     LOG_write("TX:DSM_TxInfo_24?(Port=#%d)\n", portNo)
     DSM_Send(0x24, 0x06, 0x00, 0x83, 0x5A, 0xB5) -- Still Uknown
     TX_Info_Step = 4
  elseif (TX_Info_Step == 4) then
     LOG_write("TX:DSM_TxInfo_24?(Port=#%d)\n", portNo)
     DSM_Send(0x24, 0x06, 0x06, 0x80, 0x25, 0x4B)  -- Still Uknown
     TX_Info_Step = 5
  elseif (TX_Info_Step == 5) then
     LOG_write("TX:DSM_TxInfo_END(Port=#%d)\n", portNo)
     DSM_Send(0x22, 0x04, 0x00, 0x00)
     TX_Info_Step = 0  -- Done!!
  end

  if (TX_Info_Step > 0) then
    SendDataToRX = 1 -- keep Transmitig
  end
end

local function DSM_SendUpdate(line)
  local valId = line.ValId
  local value = sInt16ToDsm(line.Val)

  LOG_write("TX:ChangeValue(VId=0x%04X,Val=%d)\n", valId, line.Val)
  DSM_Send(0x18, 0x06,
      int16_MSB(valId), int16_LSB(valId),
      int16_MSB(value), int16_LSB(value))  -- send current values
end

local function DSM_SendValidate(line)
  local valId = line.ValId
  LOG_write("TX:ValidateValue(VId=0x%04X)\n", valId)
  DSM_Send(0x19, 0x04, int16_MSB(valId), int16_LSB(valId))
end

local function DSM_SendRequest()
  --LOG_write("DSM_SendRequest  Phase=%d\n",Phase)
  -- Need to send a request
  local menuId  = Menu.MenuId
  local menuLSB = int16_LSB(menuId)
  local menuMSB = int16_MSB(menuId)

  if Phase == PH_RX_VER then   -- request RX version
    DSM_Send(0x11, 0x06, TX_MAX_CH, TX_FIRMWARE_VER, 0x00, 0x00)
    LOG_write("TX:GetVersion(TX_MAX_CH=%d, TX_FIRMWARE = 0x%02X)\n",TX_MAX_CH+6, TX_FIRMWARE_VER)

  elseif Phase == PH_WAIT_CMD then     -- keep connection open
    DSM_Send(0x00, 0x04, 0x00, 0x00) -- HB
    LOG_write("TX:TxHb\n")

  elseif Phase == PH_TITLE then     -- request menu title
    DSM_Send(0x16, 0x06, menuMSB, menuLSB, 0x00, ctx_SelLine)
    if (menuId == 0x0001) then -- Executed Save&Reset menu
      Phase = PH_RX_VER
      ctx_isReset = true
    end
    LOG_write("TX:GetMenu(M=0x%04X,L=%d)\n", menuId, ctx_SelLine)

  elseif Phase == PH_TX_INFO then -- TX Info
    SendTxInfo(ctx_CurLine)

  elseif Phase == PH_VAL_EDITING then --  Editing a line (like a HB)
    local line = MenuLines[ctx_SelLine]
    if (line.Type == LT_LIST_TOG) then -- Dont send it for Toggle options
      Phase = PH_WAIT_CMD
    else
      DSM_Send(0x1A, 0x04, 0x00, ctx_SelLine)
      LOG_write("TX:EditingValueLine(L=%d)\n", ctx_SelLine)
    end

  elseif Phase == PH_VAL_CHANGING then  -- change value during editing
    local line = MenuLines[ctx_SelLine]
    if (Change_Step==0) then
      DSM_SendUpdate(line)
      if line.Type == LT_LIST or line.Type == LT_LIST_TOG then -- Incremental Validation??
        Change_Step=1
        SendDataToRX=1
      end
    else -- Change_Step==1
      DSM_SendValidate(line)
      Change_Step=0
      Phase = PH_VAL_EDITING
    end
 
  elseif Phase == PH_VAL_EDIT_END then -- Done Editing line 
    local line = MenuLines[ctx_SelLine]
    if (line.Type == LT_LIST_TOG) then -- Dont send it for Toggle options
      Phase = PH_WAIT_CMD
    elseif (Change_Step==0) then
      DSM_SendUpdate(line)
      Change_Step=1
      SendDataToRX=1
    elseif (Change_Step==1) then
      DSM_SendValidate(line)
      Change_Step=2
      SendDataToRX=1
    else -- Change_Step==3
      LOG_write("TX:EditValueEnd(L=%d)\n", ctx_SelLine)
      DSM_Send(0x1B, 0x04, 0x00, ctx_SelLine)
      Change_Step=0
    end

  elseif Phase == PH_EXIT_REQ then -- EXIT Request 
    DSM_Send(0x1F, 0x02, 0xAA)
    LOG_write("TX:TX Exit Request\n") 
    Phase = PH_EXIT_DONE
  end
end


local function DSM_ProcessResponse()
  local cmd = multiBuffer(11)
  if cmd == 0x01 then    -- read version
    RX_Name = Get_RxName(multiBuffer(13))
    RX_Version = multiBuffer(14) .. "." .. multiBuffer(15) .. "." .. multiBuffer(16)

    Menu.MenuId = 0
    LOG_write("RX:Version: %s %s\n", RX_Name, RX_Version)

    -- ACK Version, this will trigger getting the first menu 
    DSM_Send(0x12, 0x06, TX_MAX_CH, TX_FIRMWARE_VER)
    LOG_write("TX:AckVersion()\n")
    Phase = PH_WAIT_CMD

  elseif cmd == 0x02 then     -- read menu title
    local menu  = Menu

    menu.MenuId = Dsm_to_Int16(multiBuffer(12), multiBuffer(13))
    menu.TextId = Dsm_to_Int16(multiBuffer(14), multiBuffer(15))
    menu.Text   = Get_Text(menu.TextId)
    menu.PrevId = Dsm_to_Int16(multiBuffer(16), multiBuffer(17))
    menu.NextId = Dsm_to_Int16(multiBuffer(18), multiBuffer(19))
    menu.BackId = Dsm_to_Int16(multiBuffer(20), multiBuffer(21))

    for i = 0, 6 do     -- clear menu
      MenuLines[i] = { Type = 0, TextId=0  }
    end
    ctx_CurLine = -1
    ctx_SelLine = -1     -- highlight Back

    LOG_write("RX:Menu: Mid=0x%04X \"%s\"\n", menu.MenuId, menu.Text)

    if (menu.MenuId == 0x0001) then  -- Still in RESETTING MENU???
      Phase = PH_RX_VER
    else
      local menuId  = Menu.MenuId
      DSM_Send(0x13, 0x04, int16_MSB(menuId), int16_LSB(menuId)) -- ACK Menu
      LOG_write("TX:AckMenu()\n")
      Phase = PH_WAIT_CMD
    end

  elseif cmd == 0x03 then     -- read menu lines
    local i      = multiBuffer(14)
    local type   = multiBuffer(15)
    local line   = MenuLines[i]

    ctx_CurLine  = i

    line.lineNum = i
    line.MenuId  = Dsm_to_Int16(multiBuffer(12), multiBuffer(13))
    line.Type    = type
    line.TextId  = Dsm_to_Int16(multiBuffer(16), multiBuffer(17))
    line.Text    = Get_Text(line.TextId)
    line.ValId   = Dsm_to_Int16(multiBuffer(18), multiBuffer(19))

    -- Signed int values
    line.Min     = Dsm_to_SInt16(multiBuffer(20), multiBuffer(21))
    line.Max     = Dsm_to_SInt16(multiBuffer(22), multiBuffer(23))
    line.Def     = Dsm_to_SInt16(multiBuffer(24), multiBuffer(25))

    if line.Type == LT_MENU then
      -- nothing to do on menu entries
    elseif isListLine(line) then
      line.Val = nil                          
      line.TextStart = line.Min
      line.Def = line.Def - line.Min -- normalize default value 
      line.Max = line.Max - line.Min -- normalize max index
      line.Min = 0 -- min index
    else                                 -- default to numerical value
      line.Val = nil                     --line.Def -- use default value not sure if needed
      if (line.Min == 0 and line.Max == 100) or (line.Min == -100 and line.Max == 100) or
         (line.Min == 0 and line.Max == 150) or (line.Min == -150 and line.Max == 150) then
          line.Type = LT_VALUE_PERCENT -- Override to Value Percent
      end 
    end

    if ctx_SelLine == -1 and isSelectable(line) then -- Auto select first selectable line of the menu
      ctx_SelLine = ctx_CurLine
    end

    LOG_write("RX:Line: #%d Vid=0x%04X T=0x%02X \"%s\"\n", i, line.ValId, type, line.Text)

    if (line.MenuId~=Menu.MenuId) then  -- Going Back too fast: Stil receiving lines from previous menu 
      Menu.MenuId = line.MenuId 
    end

    local menuId  = line.MenuId
    DSM_Send(0x14, 0x06, int16_MSB(menuId), int16_LSB(menuId), 0x00, ctx_CurLine) -- ACK Line
    LOG_write("TX:AckLine()\n")
    Phase = PH_WAIT_CMD

  elseif cmd == 0x04 then     -- read menu values
    -- Identify the line and update the value
    local valId = Dsm_to_Int16(multiBuffer(14), multiBuffer(15))
    local value = Dsm_to_SInt16(multiBuffer(16), multiBuffer(17))     --Signed int

    --local updatedLine = nil
    for i = 0, 6 do     -- Find the menu line for this value
      local line = MenuLines[i]
      if line ~= nil then
        if line.Type ~= LT_MENU and line.ValId == valId then         -- identifier of ValueId stored in the line
          line.Val = value
          ctx_CurLine = i
          --updatedLine = line

          updateValText(line)

          local debugTxt = line.Val
          if isListLine(line) then
            debugTxt =  line.ValText  .. "  [" .. value .. "]" 
          end

          LOG_write("RX: Value Updated: #%d  VId=0x%04X Value=%s\n", i, valId, debugTxt)
          break
        end
      end
    end

    --if (updatedLine == nil) then
    --  LOG_write("Cannot Find Line for ValueId=%x\n", valId)
    --end

    local menuId  = Menu.MenuId
    DSM_Send(0x15, 0x06, int16_MSB(menuId), int16_LSB(menuId), int16_MSB(valId), int16_LSB(valId))
    LOG_write("TX:AckValue()\n")

  elseif cmd == 0x05 then -- Request TX info
    ctx_CurLine  = multiBuffer(12)
    TX_Info_Type = multiBuffer(13)

    LOG_write("RX:TXInfoReq: Port=%d T=0x%02X\n", ctx_CurLine, TX_Info_Type)
    Phase = PH_TX_INFO
    TX_Info_Step = 0
    SendDataToRX = 1 -- Send inmediate after

  elseif cmd == 0xA7 then -- RX EXIT Request
      Phase = PH_EXIT_DONE
      LOG_write("RX:ExitReq\n")
      DSM_Release()
      error("RX Connection Drop")

  elseif cmd == 0x00 then  -- RX Heartbeat
    --LOG_write("RX:RxHb\n")
  end

  return cmd
end

local function DSM_ReceiveBuffer()
  if (SendDataToRX==1) then  -- Sending??.
    return
  end

  local data =  multiSensor:popFrame({i2cAddress=I2C_FORWARD_PROG})
  --local data =  multiSensor:popFrame()

  if (data) then
    local i2cId = data[4] or 0
    if (i2cId ~= I2C_FORWARD_PROG) then   -- not the data we want?
      return
    end
    --LOG_write("popFrame returned data")
  end

  -- move to _multiBuffer
  if (data) then
    for i=1,16 do  -- Copy from 1 based array into array starting at Pos 10
      _multiBuffer[9+i] = data[i+3] or 0xFF
    end
  end
end

local function DSM_Send_Receive()
  DSM_ReceiveBuffer()

  --  Receive part: Process incoming messages if there is nothing to send 
  if SendDataToRX==0 and multiBuffer(10) == I2C_FORWARD_PROG  then
    local cmd = DSM_ProcessResponse()
    -- Data processed
    multiBuffer(10, 0x00)
    RXInactivityTime = getTime() + 8   -- Reset Inactivity timeout (8s)
    lcd.invalidate()
  else
    -- Check if enouth time has passed from last Received activity
    if (getTime() > RXInactivityTime and Phase==PH_WAIT_CMD) then
        DSM_Release()
        error("RX Disconnected")
    end
  end

    -- Sending part --
  if SendDataToRX == 1 then
    SendDataToRX = 0
    DSM_SendRequest()
    TXInactivityTime = getTime() + 1   -- Reset Inactivity timeout (2s)
  else
    -- Check if enouth time has passed from last transmit activity
    if getTime() > TXInactivityTime then
      SendDataToRX = 1   -- Switch to Send mode to send HB
      LOG_write("Timeout.. Switching to send\n")
      lcd.invalidate()
    end
  end
end  

-----

local function flipColor(active, activeColor, inactiveColor)
  if (active) then
    lcd.color(activeColor)
  else
    lcd.color(inactiveColor)
  end
end

local function showBitmap(x, y, imgDesc)
  local f = string.gmatch(imgDesc, '([^%|]+)')   -- Iterator over values split by '|'
  local imgName, imgMsg = f(), f()

  f = string.gmatch(imgMsg or "", '([^%:]+)')   -- Iterator over values split by ':'
  local p1, p2 = f(), f()

  lcd.drawText(x, y, p1 or "")                     -- Alternate Image MSG
  lcd.drawText(x, y + LCD_Y_LINE_HEIGHT, p2 or "") -- Alternate Image MSG

  local bitMap = lcd.loadBitmap(IMG_PATH..imgName)
  if (bitMap) then
    lcd.drawBitmap(x,y + LCD_Y_LINE_HEIGHT*2,bitMap)
  end

end


local function drawButton(x, y, text, active)
  flipColor(active,LCD_FOCUS_BGCOLOR,LCD_TEXT_BGCOLOR)
  lcd.drawFilledRectangle(x, y, LCD_W_BUTTONS, LCD_Y_LINE_HEIGHT)  
  
  flipColor(active,LCD_FOCUS_COLOR,LCD_TEXT_COLOR)
  lcd.drawText(x+3, y+1, text)
  lcd.drawRectangle(x, y, LCD_W_BUTTONS-1, LCD_Y_LINE_HEIGHT) 
end

function GetFlightModeValue(line)
  local ret = line.Text
  local val = line.Val

  if (val==nil) then return string.format(ret,"--","--") end

  local gyroNum = val >> 8
  local fmNum =   val & 0xFF
  local fmStr =  (fmNum + 1) .. ""

  -- No adjustment needed
  if (fmNum==190) then
      fmStr = "Err:Out of Range"
  end
  if (gyroNum > 0) then
      return string.format(ret,(gyroNum+1).."", fmStr)
  else
      return string.format(ret,fmStr,fmStr)
  end
end

local function DSM_Display()
  -- For Headers
  lcd.color(LCD_TEXT_COLOR)
  lcd.font(FONT_BOLD)

  --Draw RX Menu
  if Phase == PH_RX_VER then
    lcd.drawText(LCD_X_MAX/2, 0, "DSM Frwd Prog "..VERSION, TEXT_CENTERED)

    local msgId = 0x300 -- Waiting for RX
    if (ctx_isReset) then msgId=0x301 end -- Waiting for Reset
    lcd.drawText(LCD_X_MAX/2, 3 * LCD_Y_LINE_HEIGHT, Get_Text(msgId), TEXT_CENTERED) 
    return
  end

    -- display RX version
  local msg = "DSM Frwd Prog "..VERSION.."       " .. RX_Name .. " v" .. RX_Version
  lcd.drawText(LCD_X_MAX / 2, LCD_Y_LOWER_BUTTONS, msg, TEXT_CENTERED) 

  if Menu.MenuId == 0 then return end; -- No Title yet

  -- Got a Menu
  lcd.font(FONT_BOLD)
  lcd.color(LCD_TEXT_COLOR)
  lcd.drawText(LCD_X_MAX / 2, 0, Menu.Text, TEXT_CENTERED)

  if (Phase == PH_TX_INFO) then
    lcd.drawText(LCD_X_MAX / 2, 3 * LCD_Y_LINE_HEIGHT, "Sending CH"..(ctx_CurLine+1), TEXT_CENTERED) 
  end

  local y = LCD_Y_LINE_HEIGHT + 2
  for i = 0, 6 do
    lcd.font(FONT_STD)
    flipColor(i == ctx_SelLine,LCD_FOCUS_BGCOLOR,LCD_TEXT_BGCOLOR)
    lcd.drawFilledRectangle(0, y, LCD_X_MAX, LCD_Y_LINE_HEIGHT)     

    local line = MenuLines[i]

    if line.Text ~= nil then
      local heading = line.Text
      flipColor(i == ctx_SelLine,LCD_FOCUS_COLOR,LCD_TEXT_COLOR)

      if (line.TextId >= 0x8000) then     -- Flight mode
        heading = GetFlightModeValue(line)
        lcd.font(FONT_BOLD)
        lcd.drawText(LCD_X_MAX / 2, y, heading, TEXT_CENTERED) -- display text
      elseif (line.Type == LT_MENU) then
        if (isSelectable(line)) then
          -- Menu to another menu 
          lcd.drawText(1, y, heading) -- display text
        else
          -- Menu lines with no navigation.. Just Sub-Header 
          lcd.font(FONT_BOLD)
          lcd.drawText(LCD_X_MAX / 2, y, heading, TEXT_CENTERED) -- display text
        end
      else
        -- Line with Value
        lcd.drawText(1, y, heading) -- display text

        local text = nil
          if line.Val ~= nil then -- Value to display??
          text = line.ValText

          if isListLine(line) then
            local textId = line.Val + line.TextStart
            -- image??
            local offset = 0
            if (line.Type==LT_LIST_ORI) then offset = offset + 0x100 end --FH6250 hack
            local imgDesc = GetTextFromFile(List_Text_Img[textId+offset])
            
            if (imgDesc and i == ctx_SelLine) then             -- Optional Image and Msg for selected value
              showBitmap(5, LCD_Y_LINE_HEIGHT+2, imgDesc) -- 2nd line
            end
          end -- ListLine

          flipColor(ctx_EditLine == i, lcd.themeColor(THEME_WARNING_COLOR),LCD_TEXT_COLOR)
          lcd.drawText(LCD_X_MAX, y, text or "--", RIGHT) -- display value
        end -- Line with value/list
      end  -- not Flight mode
    end
    y = y + LCD_Y_LINE_HEIGHT
  end     -- for

  if Menu.BackId~=0 then
    drawButton(LCD_X_RIGHT_BUTTONS, 0, "Back", ctx_SelLine == -1)
  end

  if Menu.NextId~=0 then
    drawButton(LCD_X_RIGHT_BUTTONS, LCD_Y_LOWER_BUTTONS, "Next", ctx_SelLine == 7)
  end

  if Menu.PrevId~=0 then
    drawButton(1, LCD_Y_LOWER_BUTTONS, "Prev", ctx_SelLine == 8)
  end
end

-----------------------------------------------------------------------------------------

local function load_msg_from_file(fileName, offset, FileState)

  if (FileState.state==nil) then -- Initial State
    FileState.state=1
    FileState.lineNo=0
    FileState.filePos=0
  end

  if FileState.state==1 then
    for l=1,10 do -- do 10 lines at a time 
      local type, sIndex, text
      local lineStart = FileState.filePos

      type, sIndex, text, FileState.filePos = GetTextInfoFromFile(FileState.filePos+offset)

      --print(string.format("T=%s, I=%s, T=%s LS=%d, FP=%d",type,sIndex,text,lineStart, FileState.filePos))

      if (lineStart==FileState.filePos) then -- EOF
          FileState.state=2 --EOF State 
          return 1
      end
      FileState.lineNo = FileState.lineNo + 1

      type = rtrim(type)

      if (string.len(type) > 0 and string.len(sIndex) > 0) then
          local index = tonumber(sIndex)
          local filePos =  lineStart + offset

          if (index == nil) then
            assert(false, string.format("%s:%d: Invalid Hex num [%s]", fileName, FileState.lineNo, sIndex))
          elseif (type == "T") then
            Text[index] =  filePos
          elseif (type == "LT") then
            List_Text[index] = filePos
          elseif (type == "LI") then
            List_Text_Img[index] = filePos
          elseif (type == "FM") then
            Flight_Mode[index-0x8000] = text
          elseif (type == "RX") then
            RxName[index] = text
          else
            assert(false, string.format("%s:%d: Invalid Line Type [%s]", fileName, FileState.lineNo, type))
          end
      end
      gc()
    end -- for 
  end -- if

  return 0
end


-- Load Menu Data from a file 
local function ST_LoadFileData() 
  local MV_DATA_END        = 1040

  MODEL.hashName = "Fake-Plane"

  -- Clear Menu Data
  for i = 0, MV_DATA_END do
      M_DATA[i]=nil
  end

  print("Loading Plane Info for:"..MODEL.hashName)

  -- TODO: Read the model aircraft info from Ethos, or create a UI similar to the one in EdgeTX

  -- Wing and Tail Type
  M_DATA[MV_WING_TYPE] = WT_A1   -- One Aileron
  M_DATA[MV_TAIL_TYPE] = TT_R1_E1 -- Normal 1 Rud, 1 Ele

  -- channels for Thr, Ail, Elv, Rud
  M_DATA[MV_CH_THR] = 3  -- CH3
  
  M_DATA[MV_CH_L_AIL] = 1  -- CH1
  M_DATA[MV_CH_R_AIL] = nil

  M_DATA[MV_CH_L_ELE] = 2 -- CH2
  M_DATA[MV_CH_R_ELE] = nil

  M_DATA[MV_CH_L_RUD] = 4 -- CH4
  M_DATA[MV_CH_R_RUD] = nil

  for i=0, TX_CHANNELS-1 do
    M_DATA[MV_PORT_BASE+i]=MT_NORMAL
  end


  return 1
end

local function getModuleChannelOrder(num) 
  --Determine fist 4 channels order
  local ch_n={}
  local st_n = {[0]= "R", "E", "T", "A" }
  local c_ord=num -- ch order
  if (c_ord == -1) then
    ch_n[0] = st_n[3]
    ch_n[1] = st_n[1]
    ch_n[2] = st_n[2]
    ch_n[3] = st_n[0]
  else
    ch_n[bit32.band(c_ord,3)] = st_n[3]
    c_ord = math.floor(c_ord/4)
    ch_n[bit32.band(c_ord,3)] = st_n[1]
    c_ord = math.floor(c_ord/4)
    ch_n[bit32.band(c_ord,3)] = st_n[2]
    c_ord = math.floor(c_ord/4)
    ch_n[bit32.band(c_ord,3)] = st_n[0]
  end

  local s = ""
  for i=0,3 do
    s=s..ch_n[i]
  end
  return s
end

local function ReadTxModelData()
  local TRANSLATE_AETR_TO_TAER=false
  local table = model.getInfo()   -- Get the model name 
  MODEL.modelName = table.name

  local module = model.getModule(0) -- Internal
  if (module==nil or module.Type~=6) then module = model.getModule(1) end -- External
  if (module~=nil) then
      if (module.Type==6 ) then -- MULTI-MODULE
          local chOrder = module.channelsOrder
          local s = getModuleChannelOrder(chOrder)
          LOG_write("MultiChannel Ch Order: [%s]  %s\n",chOrder,s) 

          if (s=="AETR") then TRANSLATE_AETR_TO_TAER=true 
          else TRANSLATE_AETR_TO_TAER=false 
          end
      end
  end

  -- Read Ch1 to Ch10
  local i= 0
  for i = 0, TX_CHANNELS-1 do 
      local ch = model.getOutput(i) -- Zero base 
      if (ch~=nil) then
          MODEL.modelOutputChannel[i] = ch
          if (string.len(ch.name)==0) then 
              ch.formatCh = string.format("TX:Ch%i",i+1)
          else
              ch.formatCh = string.format("TX:Ch%i/%s",i+1,ch.name or "--")
          end
      end
  end

  -- Translate AETR to TAER

  if (TRANSLATE_AETR_TO_TAER) then 
      LOG_write("Applying  AETR -> TAER translation\n") 
      local ail = MODEL.modelOutputChannel[0]
      local elv = MODEL.modelOutputChannel[1]
      local thr = MODEL.modelOutputChannel[2]

      MODEL.modelOutputChannel[0] = thr
      MODEL.modelOutputChannel[1] = ail
      MODEL.modelOutputChannel[2] = elv
  end

  -- Create the Port Text to be used 
  LOG_write("Ports/Channels:\n") 
  for i = 0, TX_CHANNELS-1 do 
      local ch =  MODEL.modelOutputChannel[i]
      if (ch~=nil) then
          MODEL.TX_CH_TEXT[i] = ch.formatCh
          MODEL.PORT_TEXT[i] = string.format("P%i (%s) ",i+1,MODEL.TX_CH_TEXT[i])  
          LOG_write("Port%d %s [%d,%d] Rev=%d, Off=%d, ppmC=%d, syn=%d\n",i+1,MODEL.TX_CH_TEXT[i],math.floor(ch.min/10),math.floor(ch.max/10), ch.revert, ch.offset, ch.ppmCenter, ch.symetrical)
      end
  end
end

local function channelType2String(byte1, byte2) 
  local s = ""

  if (byte2==0) then return s end;
  
  if (bit32.band(byte2,CT_AIL)>0) then s=s.."Ail" end
  if (bit32.band(byte2,CT_ELE)>0) then s=s.."Ele" end
  if (bit32.band(byte2,CT_RUD)>0) then s=s.."Rud" end
  if (bit32.band(byte2,CT_THR)>0) then s=s.."Thr" end

  if (bit32.band(byte2,CT_REVERSE)>0) then s=s.."-" end

  if (bit32.band(byte2,CT_SLAVE)>0) then s=s.." Slv" end

  if (byte1==CMT_NORM) then s=s.." " 
  elseif (byte1==CMT_AIL) then s=s.." M_Ail" 
  elseif (byte1==CMT_ELE) then s=s.." M_Ele" 
  elseif (byte1==CMT_RUD) then s=s.." M_Rud" 
  elseif (byte1==CMT_RUD_REV) then s=s.." M_Rud-" 
  elseif (byte1==CMT_ELE_REV) then s=s.." M_Ele-" 
  elseif (byte1==CMT_AIL_REV) then s=s.." M_Ail-" 
  elseif (byte1==CMT_NORM_REV) then s=s.." M-" 
  end

  return s;
end

-- This Creates the Servo Settings that will be used to pass to 
-- Forward programming
local function CreateDSMPortChannelInfo()

  local function ApplyWingMixA(b2)
      -- ELEVON
      if (b2==CT_AIL+CT_ELE) then return CMT_ELE end; -- 0x03
      if (b2==CT_AIL+CT_ELE+CT_SLAVE) then return CMT_NORM end; -- 0x83
  end

  local function ApplyWingMixB(b2)
      -- ELEVON 
      if (b2==CT_AIL+CT_ELE) then return CMT_NORM end; -- 0x03
      if (b2==CT_AIL+CT_ELE+CT_SLAVE) then return CMT_ELE end; -- 0x83
 end

  local function ApplyTailMixA(b2)
      -- VTAIL
      -- Default normal/reverse behaviour 
      if (b2==CT_RUD+CT_ELE) then return CMT_NORM end; -- 0x06
      if (b2==CT_RUD+CT_ELE+CT_SLAVE) then return CMT_ELE end; -- 0x86

      --TAILERON
      -- Default normal/reverse behaviour 
      if (b2==CT_AIL+CT_ELE) then return CMT_NORM end; -- 0x03
      if (b2==CT_AIL+CT_ELE+CT_SLAVE) then return CMT_AIL end; -- 0x83
  end

  local function ApplyTailMixB(b2)
      -- VTAIL 
      -- Default normal/reverse behaviour 
      if (b2==CT_RUD+CT_ELE) then return CMT_NORM end; -- 0x06
      if (b2==CT_RUD+CT_ELE+CT_SLAVE) then return CMT_RUD end; -- 0x86

      --TAILERON
      if (b2==CT_AIL+CT_ELE) then return CMT_AIL end; -- 0x03
      if (b2==CT_AIL+CT_ELE+CT_SLAVE) then return CMT_NORM end; -- 0x83
  end

  local function reverseMix(b)
      if (b==CMT_NORM) then return CMT_NORM_REV end;
      if (b==CMT_AIL) then return CMT_AIL_REV end;
      if (b==CMT_ELE) then return CMT_ELE_REV end;
      if (b==CMT_RUD) then return CMT_RUD_REV end;
      return b
  end

  local DSM_Ch = MODEL.DSM_ChannelInfo 

  for i=0, TX_CHANNELS-1 do
      DSM_Ch[i] = {[0]= CMT_NORM, CT_NONE, nil}  -- Initialize with no special function 
  end

  --local aircraftType = M_DATA[MV_AIRCRAFT_TYPE]
  local wingType = M_DATA[MV_WING_TYPE]
  local tailType = M_DATA[MV_TAIL_TYPE]

  local thrCh  =  M_DATA[MV_CH_THR]
  local lAilCh =  M_DATA[MV_CH_L_AIL]
  local rAilCh =  M_DATA[MV_CH_R_AIL]

  local lElevCh = M_DATA[MV_CH_L_ELE]
  local rElevCh = M_DATA[MV_CH_R_ELE]

  local lRudCh = M_DATA[MV_CH_L_RUD]
  local rRudCh = M_DATA[MV_CH_R_RUD]

  -- Channels in menu vars are Zero base, Channel info is 1 based 
  
  -- THR 
  if (thrCh~=nil and thrCh < 10) then DSM_Ch[thrCh][1]= CT_THR end

  -- AIL (Left and Right)
  if (lAilCh~=nil) then DSM_Ch[lAilCh][1] = CT_AIL  end
  if (rAilCh~=nil) then DSM_Ch[rAilCh][1] = CT_AIL+CT_SLAVE end
  -- ELE (Left and Right)
  if (lElevCh~=nil) then DSM_Ch[lElevCh][1] = CT_ELE end
  if (rElevCh~=nil) then DSM_Ch[rElevCh][1] = CT_ELE+CT_SLAVE end
  -- RUD (Left and Right)
  if (lRudCh~=nil) then DSM_Ch[lRudCh][1] = CT_RUD end
  if (rRudCh~=nil) then DSM_Ch[rRudCh][1] = CT_RUD+CT_SLAVE end

  -- VTAIL: RUD + ELE
  if (tailType==TT_VT_A) then 
      DSM_Ch[lElevCh][1] = CT_RUD+CT_ELE
      DSM_Ch[rElevCh][1] = CT_RUD+CT_ELE+CT_SLAVE
  elseif (tailType==TT_VT_B) then
      DSM_Ch[lElevCh][1] = CT_RUD+CT_ELE+CT_SLAVE
      DSM_Ch[rElevCh][1] = CT_RUD+CT_ELE
  end

  -- TAILERRON: 2-ELE + AIL
  if (tailType==TT_TLRN_A or tailType==TT_TLRN_A_R2) then 
      DSM_Ch[lElevCh][1] = CT_AIL+CT_ELE
      DSM_Ch[rElevCh][1] = CT_AIL+CT_ELE+CT_SLAVE
  elseif (tailType==TT_TLRN_B or tailType==TT_TLRN_B_R2) then
      DSM_Ch[lElevCh][1] = CT_AIL+CT_ELE+CT_SLAVE
      DSM_Ch[rElevCh][1] = CT_AIL+CT_ELE
  end

  ---- ELEVON :  AIL + ELE 
  if (wingType==WT_ELEVON_A) then 
      DSM_Ch[lAilCh][1] = CT_AIL+CT_ELE
      DSM_Ch[rAilCh][1] = CT_AIL+CT_ELE+CT_SLAVE
  elseif (wingType==WT_ELEVON_B) then
      DSM_Ch[lAilCh][1] = CT_AIL+CT_ELE+CT_SLAVE
      DSM_Ch[rAilCh][1] = CT_AIL+CT_ELE
  end

 ------MIXES ---------

  -- TAIL Mixes (Elevator and VTail)
  if (tailType==TT_VT_A or tailType==TT_TLRN_A or tailType==TT_TLRN_A_R2) then 
      DSM_Ch[lElevCh][0] = ApplyTailMixA(DSM_Ch[lElevCh][1])
      DSM_Ch[rElevCh][0] = ApplyTailMixA(DSM_Ch[rElevCh][1])
  elseif (tailType==TT_VT_B or tailType==TT_TLRN_B or tailType==TT_TLRN_B_R2) then
      DSM_Ch[lElevCh][0] = ApplyTailMixB(DSM_Ch[lElevCh][1])
      DSM_Ch[rElevCh][0] = ApplyTailMixB(DSM_Ch[rElevCh][1])
  end

   ---- ELEVON :  AIL + ELE 
   if (wingType==WT_ELEVON_A) then 
      DSM_Ch[lAilCh][0] = ApplyWingMixA(DSM_Ch[lAilCh][1])
      DSM_Ch[rAilCh][0] = ApplyWingMixA(DSM_Ch[rAilCh][1])
  elseif (wingType==WT_ELEVON_B) then
      DSM_Ch[lAilCh][0] = ApplyWingMixB(DSM_Ch[lAilCh][1])
      DSM_Ch[rAilCh][0] = ApplyWingMixB(DSM_Ch[rAilCh][1])
  end

  -- Apply Gyro Reverse as needed for each channel as long as it is used 
  for i=0, TX_CHANNELS-1 do
      if (M_DATA[MV_PORT_BASE+i]==MT_REVERSE and DSM_Ch[i][1]>0) then
          DSM_Ch[i][0]=reverseMix(DSM_Ch[i][0])
          DSM_Ch[i][1]=DSM_Ch[i][1]+CT_REVERSE
      end
  end

  -- Show how it looks
  for i=0, 9 do
      local b1,b2 =  DSM_Ch[i][0], DSM_Ch[i][1]
      local s1 =  channelType2String(b1,b2)
      local s = string.format("%s (%02X %02X)  %s\n", MODEL.PORT_TEXT[i],
                  b1, b2,s1)
      DSM_Ch[i][2]=s1
      LOG_write(s) 
  end

  --MODEL.AirWingTailDesc = string.format("Aircraft(%s) Wing(%s) Tail(%s)",aircraft_type_text[aircraftType],wing_type_text[wingType],tail_type_text[tailType])
end

------------------------------------------------------------------------------------------------------------
-- Init
local function DSM_Init()
  LOG_open()
  LOG_write("--- NEW SESSION\n")

  --DSM_Init_Model()

  Phase = PH_INIT

  --ReadTxModelData()
  --local r = ST_LoadFileData()
  --if (r == 1) then
  --  LOG_write("Creating DSMPort Info\n")
  --  CreateDSMPortChannelInfo()
  --else
  --  assert(true,"Cannot load file")
  --end
  M_DATA = nil
  MODEL.PORT_TEXT = nil
  gc()
end


-----------------------------------------------------------------------------------------------------------
local initStep=0
local FileState = { lineNo=0 }

local function Inc_Init_paint()
  lcd.drawText(1, 0, "Loading Msg file: "..(FileState.lineNo or 0))
end

local function Inc_Init() 
  print("Loading Msg file: "..(FileState.lineNo or 0))
  
  lcd.invalidate()
  if (initStep == 0) then
    if (load_msg_from_file(MSG_FILE, 0, FileState)==1) then
      initStep=1
      FileState = {}
    end
  else 
    Phase = PH_RX_VER -- Done Init
    DSM_Connect()
  end
end


local lastGoodMenu = 0
local RX_Initialized = 1

local function AR631_Menus(menuId)
  if (menuId==0) then menuId = 0x1000 end

  ctx_CurLine = -1
  ctx_SelLine = -1     -- highlight Back

  for i = 0, 6 do     -- clear menu
    MenuLines[i] = { Type = 0, TextId=0  }
  end

  if (menuId==0x0001) then 
    -- Save Settings and Reboot
    Menu = { MenuId = 0x0001, TextId = 0x009F, PrevId = 0, NextId = 0, BackId = 0x1000 }
    ctx_SelLine = -1 -- BACK

  elseif (menuId == 0x1000) then
    Menu = { MenuId = 0x1000, TextId = 0x004B, PrevId = 0, NextId = 0, BackId = 0 }
    MenuLines[0] = { Type = LT_MENU, TextId = 0x00F9, ValId = 0x1010 }
    MenuLines[1] = { Type = LT_MENU, TextId = 0x0227, ValId = 0x105E }    
    ctx_SelLine = 0 
    lastGoodMenu = menuId
  elseif (menuId==0x1010) then
    Menu = { MenuId = 0x1010, TextId = 0x00F9, PrevId = 0, NextId = 0, BackId = 0x1000 }
    if not RX_Initialized then 
        MenuLines[5] = { Type = LT_MENU, TextId = 0x00A5, ValId = 0x104F}
        MenuLines[6] = { Type = LT_MENU, TextId = 0x020D, ValId = 0x1055}
        ctx_SelLine = 5
    else
        MenuLines[0] = { Type = LT_MENU, TextId = 0x01DD, ValId = 0x1011 }
        MenuLines[1] = { Type = LT_MENU, TextId = 0x01E2, ValId = 0x1019 }
        MenuLines[2] = { Type = LT_MENU, TextId = 0x0087, ValId = 0x1021 }
        MenuLines[3] = { Type = LT_MENU, TextId = 0x0086, ValId = 0x1022 }
        MenuLines[4] = { Type = LT_MENU, TextId = 0x01F9, ValId = 0x105C }
        ctx_SelLine = 0
    end
    lastGoodMenu = menuId
  elseif (menuId==0x1011) then
    Menu = { MenuId = 0x1011, TextId = 0x1DD, PrevId = 0, NextId = 0, BackId = 0x1010 }
    MenuLines[0] = { Type = LT_MENU, TextId = 0x1DE, ValId = 0x1012}
    MenuLines[1] = { Type = LT_MENU, TextId = 0x46, ValId = 0x1013}
    MenuLines[2] = { Type = LT_MENU, TextId = 0x82, ValId = 0x1015}
    MenuLines[4] = { Type = LT_LIST_NC, TextId = 0x8A, ValId = 0x1004, Min=0, Max=244, Def=50, Val=50 }
    MenuLines[5] = { Type = LT_MENU, TextId = 0x263, ValId = 0x1016}
    MenuLines[6] = { Type = LT_MENU, TextId = 0xAA, ValId = 0x1017 }
    ctx_SelLine = 0
    lastGoodMenu = menuId
  elseif (menuId==0x1012) then
    -- M[Id=0x1012 P=0x0 N=0x0 B=0x1011 Text="AS3X Gains"[0x1DE]]
    --L[#0 T=V_nc VId=0x1000 Text="Flight Mode 1"[0x8001] val=1 [0->10,0] MId=0x1012 ]
    --L[#2 T=M    VId=0x1012 Text="Rate Gains"[0x1E0] MId=0x1012 ]
    --L[#3 T=V_nc VId=0x1004 Text="Roll"[0x40] val=14 [0->100,40] MId=0x1012 ]
    --L[#4 T=V_nc VId=0x1005 Text="Pitch"[0x41] val=29 [0->100,50] MId=0x1012 ]
    --L[#5 T=V_nc VId=0x1006 Text="Yaw"[0x42]  val=48 [0->100,60] MId=0x1012 ]

    Menu = { MenuId = 0x1012, TextId = 0x1DE, PrevId = 0, NextId = 0, BackId = 0x1011 }
    MenuLines[0] = { Type = LT_VALUE_NC, TextId = 0x8001, ValId = 0x1000, Min=0, Max=10, Def=0, Val=1 }
    MenuLines[2] = { Type = LT_MENU,     TextId = 0x1E0, ValId = 0x1012 }
    MenuLines[3] = { Type = LT_VALUE_NC, TextId = 0x40, ValId = 0x1004, Min=0, Max=100, Def=40, Val=40 }
    MenuLines[4] = { Type = LT_VALUE_NC, TextId = 0x41, ValId = 0x1005, Min=0, Max=100, Def=50, Val=50 }
    MenuLines[5] = { Type = LT_VALUE_NC, TextId = 0x42, ValId = 0x1006, Min=0, Max=100, Def=60, Val=60 }

    ctx_SelLine = 3
    lastGoodMenu = menuId
  elseif (menuId==0x1013) then
    --M[Id=0x1013 P=0x0 N=0x0 B=0x1011 Text="Priority"[0x46]]
    --L[#0 T=V_nc VId=0x1000 Text="Flight Mode 1"[0x8001] val=1 [0->10,0] MId=0x1012 ]
    --L[#1 T=M VId=0x1013 Text="Stick Priority"[0xFE] MId=0x1013 ]
    --L[#3 T=V_nc VId=0x1004  Text="Roll"[0x40] val=14 [0->160,160] MId=0x1012 ]
    --L[#4 T=V_nc VId=0x1005  Text="Pitch"[0x41] val=29 [0->160,160] MId=0x1012 ]
    --L[#5 T=V_nc VId=0x1006  Text="Yaw"[0x42] val=48 [0->160,160] MId=0x1012 ]

    Menu = { MenuId = 0x1013, TextId = 0x46, PrevId = 0, NextId = 0, BackId = 0x1011 }
    MenuLines[0] = { Type = LT_VALUE_NC, TextId = 0x8001, ValId = 0x1000, Min=0, Max=10, Def=0, Val=1 }
    MenuLines[2] = { Type = LT_MENU,     TextId = 0xFE, ValId = 0x1013 }
    MenuLines[3] = { Type = LT_VALUE_NC, TextId = 0x40, ValId = 0x1004, Min=0, Max=160, Def=100, Val=160 }
    MenuLines[4] = { Type = LT_VALUE_NC, TextId = 0x41, ValId = 0x1005, Min=0, Max=160, Def=100, Val=160 }
    MenuLines[5] = { Type = LT_VALUE_NC, TextId = 0x42, ValId = 0x1006, Min=0, Max=160, Def=100, Val=160 }

    ctx_SelLine = 3
    lastGoodMenu = menuId
elseif (menuId==0x1015) then
    -- M[Id=0x1015 P=0x0 N=0x0 B=0x1011 Text="Heading Gain"[0x266]]
    -- L[#0T=V_nc VId=0x1000 Text="Flight Mode 1"[0x8001] val=1 [0->10,0] MId=0x1015 ]
    -- L[#1 T=M VId=0x1015 Text="Heading Gain"[0x266] MId=0x1015 ]
    -- L[#2 T=V_nc VId=0x1004 Text="Roll"[0x40] val=0 [0->100,0] MId=0x1015  ]
    -- L[#3 T=V_nc VId=0x1005 Text="Pitch"[0x41] val=0 [0->100,0] MId=0x1015 ]
    -- L[#5 T=M VId=0x1015 Text="Use CAUTION for Yaw gain!"[0x26A] MId=0x1015 ]
    -- L[#6T=V_nc VId=0x1006 Text="Yaw"[0x42] val=0 [0->100,0] MId=0x1015 ]

    Menu = { MenuId = 0x1015, TextId = 0x266, PrevId = 0, NextId = 0, BackId = 0x1011 }
    MenuLines[0] = { Type = LT_VALUE_NC, TextId = 0x8001, ValId = 0x1000, Min=0, Max=10, Def=0, Val=1 }
    MenuLines[1] = { Type = LT_MENU,     TextId = 0x1F9, ValId = 0x1015 }
    MenuLines[2] = { Type = LT_VALUE_NC, TextId = 0x40, ValId = 0x1004, Min=0, Max=100, Def=0, Val=0 }
    MenuLines[3] = { Type = LT_VALUE_NC, TextId = 0x41, ValId = 0x1005, Min=0, Max=100, Def=0, Val=0 }
    MenuLines[5] = { Type = LT_MENU,     TextId = 0x26A, ValId = 0x1015 }
    MenuLines[6] = { Type = LT_VALUE_NC, TextId = 0x42, ValId = 0x1006, Min=0, Max=100, Def=0, Val=0 }
    ctx_SelLine = 2
    lastGoodMenu = menuId
  elseif (menuId==0x1021) then
    --M[Id=0x1021 P=0x0 N=0x0 B=0x1010 Text="F-Mode Setup"[0x87]]
    --L[#0 T=V_nc VId=0x1000 Text="Flight Mode 1"[0x8001] val=1 [0->10,0] MId=0x1021 ]
    --L[#1 T=M VId=0x7CA6 Text="FM Channel"[0x78] MId=0x1021 ]
    --L[#2 T=LM VId=0x1002 Text="AS3X"[0x1DC] val=1 (0->1,3,S=3) [3->4|3] MId=0x1021]
    
    --L[#3 T=LM VId=0x1003 Text="Safe Mode"[0x1F8] val=3|"Inh" NL=(0->244,0,S=0) [0->244,3]  MId=0x1021 ]
    --L[#3 T=LM VId=0x1003 Text="Safe Mode"[0x1F8] val=176|"Self-Level/Angle Dem" NL=(0->244,0,S=0) [0->244,3]  MId=0x1021 ]
    
    --L[#4 T=LM VId=0x1004 Text="Panic"[0x8B] val=0 NL=(0->1,3,S=3) [3->4,3] MId=0x1021 ]
    --L[#5 T=LM VId=0x1005 Text="High Thr to Pitch"[0x1F0]  val=0 NL=(0->1,3,S=3) [3->4,3] MId=0x1021 ]
    --L[#6 T=LM VId=0x1006 Text="Low Thr to Pitch"[0x1EF] val=0 NL=(0->1,3,S=3) [3->4,3] MId=0x1021 ]

     Menu = { MenuId = 0x1021, TextId = 0x87, PrevId = 0, NextId = 0, BackId = 0x1010 }
     MenuLines[0] = { Type = LT_VALUE_NC, TextId = 0x8001, ValId = 0x1000, Min=0, Max=10, Def=0, Val=1 }
     MenuLines[1] = { Type = LT_MENU, TextId = 0x78, ValId = 0x7CA6 }
     MenuLines[2] = { Type = LT_LIST, TextId = 0x1DC, ValId = 0x1002, Min=3, Max=4, Def=3, Val=4 }
     MenuLines[3] = { Type = LT_LIST, TextId = 0x1F8, ValId = 0x1003, Min=0, Max=244, Def=3, Val=176 }
     MenuLines[4] = { Type = LT_LIST, TextId = 0x8B, ValId = 0x1004, Min=3, Max=4, Def=3, Val=3 }
     MenuLines[5] = { Type = LT_LIST, TextId = 0x1F0, ValId = 0x1005, Min=3, Max=4, Def=3, Val=3 }
     MenuLines[6] = { Type = LT_LIST, TextId = 0x1EF, ValId = 0x1006, Min=3, Max=4, Def=3, Val=3 }
     ctx_SelLine = 1
     lastGoodMenu = menuId
    elseif (menuId==0x7CA6) then
      --M[Id=0x7CA6 P=0x0 N=0x1021 B=0x1021 Text="FM Channel"[0x78]]
      --L[#0 T=LM VId=0x1000 Text="FM Channel"[0x78] val=7 N=(0->32,53,S=53) [53->85,53] MId=0x7CA6 ]

      Menu = { MenuId = 0x7CA6, TextId = 0x78, PrevId = 0, NextId = 0x1021, BackId = 0x1021 }
      MenuLines[0] = { Type = LT_LIST, TextId = 0x78, ValId = 0x1000, Min=53, Max=85, Def=53, Val=53 }
      
      ctx_SelLine = 0
      lastGoodMenu = menuId
    elseif (menuId==0x1022) then  
      --M[Id=0x1022 P=0x0 N=0x0 B=0x1010 Text="System Setup"[0x86]]
      --L[#0 T=M VId=0x1023 Text="Relearn Servo Settings"[0x190] MId=0x1022 ]
      --L[#1 T=M VId=0x1025 Text="Orientation"[0x80] MId=0x1022 ]
      --L[#2 T=M VId=0x1029 Text="Gain Channel Select"[0xAD] MId=0x1022 ]
      --L[#3 T=M VId=0x102A Text="SAFE/Panic Mode Setup"[0xCA] MId=0x1022 ]
      --L[#4 T=M VId=0x1032 Text="Utilities"[0x240] MId=0x1022 ]

      Menu = { MenuId = 0x1022, TextId = 0x86, PrevId = 0, NextId = 0, BackId = 0x1010  }
      MenuLines[0] = { Type = LT_MENU, TextId = 0x190, ValId = 0x1023  }
      MenuLines[1] = { Type = LT_MENU, TextId = 0x80, ValId = 0x1025  }
      MenuLines[2] = { Type = LT_MENU, TextId = 0xAD, ValId = 0x1029 }
      MenuLines[3] = { Type = LT_MENU, TextId = 0xCA, ValId = 0x102A }
      MenuLines[4] = { Type = LT_MENU, TextId = 0x240, ValId = 0x1032 }
      ctx_SelLine = 0
      lastGoodMenu = menuId
    elseif (menuId==0x1023) then  
      --M[Id=0x1023 P=0x0 N=0x0 B=0x1022 Text="Relearn Servo Settings"[0x190]]
      --L[#3 T=M VId=0x1024 Text="Apply"[0x90]   MId=0x1023 ]
  
      Menu = { MenuId = 0x1023, TextId = 0x190, PrevId = 0, NextId = 0, BackId = 0x1022  }
      MenuLines[3] = { Type = LT_MENU, TextId = 0x90, ValId = 0x1024  }
      
      ctx_SelLine = 3
      lastGoodMenu = menuId
  elseif (menuId==0x1024) then  
      --M[Id=0x1024 P=0x0 N=0x0 B=0x0 Text="Relearn Servo Settings"[0x190]]
      --L[#3 T=M VId=0x1000 Text="Complete"[0x93]   MId=0x1024 ]

      Menu = { MenuId = 0x1024, TextId = 0x190, PrevId = 0, NextId = 0, BackId = 0  }
      MenuLines[3] = { Type = LT_MENU, TextId = 0x93, ValId = 0x1000  }
      
      ctx_SelLine = 3
      lastGoodMenu = menuId

  elseif (menuId==0x1025) then 
      --M[Id=0x1025 P=0x0 N=0x0 B=0x1022 Text="Orientation"[0x80]]
      --L[#0 T=M VId=0x1025 Text="Set the model level,"[0x21A]   MId=0x1025 ]
      --L[#1 T=M VId=0x1025 Text="and press Continue."[0x21B]   MId=0x1025 ]
      --L[#2 T=M VId=0x1025 Text=""[0x21C]   MId=0x1025 ]
      --L[#3 T=M VId=0x1025 Text=""[0x21D]   MId=0x1025 ]
      --L[#5 T=M VId=0x1026 Text="Continue"[0x224]   MId=0x1025 ]
      --L[#6 T=M VId=0x1027 Text="Set Orientation Manually"[0x229]   MId=0x1025 ]

      Menu = { MenuId = 0x1025, TextId = 0x80, PrevId = 0, NextId = 0, BackId = 0x1022 }
      MenuLines[0] = { Type = LT_MENU, TextId = 0x21A, ValId = 0x1025 }
      MenuLines[1] = { Type = LT_MENU, TextId = 0x21B, ValId = 0x1025 }
      MenuLines[2] = { Type = LT_MENU, TextId = 0x21C, ValId = 0x1025 }
      MenuLines[3] = { Type = LT_MENU, TextId = 0x21D, ValId = 0x1025 }
      MenuLines[5] = { Type = LT_MENU, TextId = 0x224, ValId = 0x1026 }
      MenuLines[6] = { Type = LT_MENU, TextId = 0x229, ValId = 0x1027 }
      ctx_SelLine = 5
      lastGoodMenu = menuId
  elseif (menuId==0x1026) then 
      --M[Id=0x1026 P=0x1025 N=0x0 B=0x1025 Text="Orientation"[0x80]]
      --L[#0 T=M VId=0x1026 Text="Set the model on its nose,"[0x21F]   MId=0x1026 ]
      --L[#1 T=M VId=0x1026 Text="and press Continue. If the"[0x220]   MId=0x1026 ]
      --L[#2 T=M VId=0x1026 Text="orientation on the next"[0x221]   MId=0x1026 ]
      --L[#3 T=M VId=0x1026 Text="screen is wrong go back"[0x222]   MId=0x1026 ]
      --L[#4 T=M VId=0x1026 Text="and try again."[0x223]   MId=0x1026 ]
      --L[#6 T=M VId=0x1027 Text="Continue"[0x224]   MId=0x1026 ]

      Menu = { MenuId = 0x1026, TextId = 0x80, PrevId = 0x1025, NextId = 0, BackId = 0x1025 }
      MenuLines[0] = { Type = LT_MENU, TextId = 0x21F, ValId = 0x1026 }
      MenuLines[1] = { Type = LT_MENU, TextId = 0x220, ValId = 0x1026 }
      MenuLines[2] = { Type = LT_MENU, TextId = 0x221, ValId = 0x1026 }
      MenuLines[3] = { Type = LT_MENU, TextId = 0x222, ValId = 0x1026 }
      MenuLines[4] = { Type = LT_MENU, TextId = 0x223, ValId = 0x1026 }
      MenuLines[6] = { Type = LT_MENU, TextId = 0x224, ValId = 0x1027 }

      ctx_SelLine = 6
      lastGoodMenu = menuId
  elseif (menuId==0x1027) then 
      --M[Id=0x1028 P=0x0 N=0x0 B=0x1028 Text="Orientation"[0x80]]
      --L[#5 T=LM_nc VId=0x1000 Text="Orientation"[0x80] Val=4|"RX Pos 5" NL=(0->23,0,S=203) [203->226,203] MId=0x1027 ]
      --L[#6 T=M VId=0x1028 Text="Continue"[0x224]   MId=0x1027 ]

      Menu = { MenuId = 0x1027, TextId = 0x80, PrevId = 0x1025, NextId = 0, BackId = 0x1025 }
      MenuLines[5] = { Type = LT_LIST_NC, TextId = 0x80, ValId = 0x1000, Min=203, Max=226, Def=203, Val=208 }
      MenuLines[6] = { Type = LT_MENU, TextId = 0x224, ValId = 0x1028 }
      ctx_SelLine = 5
      lastGoodMenu = menuId
  elseif (menuId==0x1028) then 
      --M[Id=0x1027 P=0x1025 N=0x0 B=0x1025 Text="Orientation"[0x80]]
      --L[#2 T=M VId=0x1 Text="Resetting RX... "[0x9F]   MId=0x1028 ]
      --L[#3 T=M VId=0x1028 Text="RX Pos 7"[0xD1]   MId=0x1028 ]

      Menu = { MenuId = 0x1028, TextId = 0x80, PrevId = 0x1025, NextId = 0, BackId = 0x1025 }
      MenuLines[2] = { Type = LT_MENU, TextId = 0x9F, ValId = 0x1 }
      MenuLines[3] = { Type = LT_MENU, TextId = 0xD1, ValId = 0x1028 }
      ctx_SelLine = 2
      lastGoodMenu = menuId
  else
    Menu = { MenuId = menuId, TextId = 0, Text=string.format("Not Implemented Menu[0x%04x]",menuId), PrevId = 0, NextId = 0, BackId = lastGoodMenu }
    ctx_SelLine = -1
  end

  -- PostProcess
  if (Menu.TextId > 0) then
    Menu.Text = Get_Text(Menu.TextId)
  end

  for i = 0, 6 do     -- Set Text
    local line = MenuLines[i]
    if (line.TextId > 0) then
      line.MenuId = Menu.MenuId;
      line.Text = Get_Text(line.TextId)

      if isListLine(line) then                         
        line.TextStart = line.Min
        line.Def = line.Def - line.Min -- normalize default value 
        line.Max = line.Max - line.Min -- normalize max index
        line.Min = 0 -- min index
        line.Val = line.Val - line.TextStart
      end
    end
    updateValText(line)
  end
end

local function DSM_Sim_RX()
  if (Phase==PH_EXIT_REQ) then
    system.exit()
  end
  if (Phase == PH_RX_VER) then
    RX_Name = Get_RxName(0x16)
    RX_Version = "1.3.4"
    Menu.MenuId = 0
    Phase = PH_TITLE
    LOG_write("Sim-RX:Version: %s %s\n", RX_Name, RX_Version)
    lcd.invalidate()
  elseif (Phase == PH_TITLE) then
    AR631_Menus(Menu.MenuId)
    LOG_write("Sim-RX:Menu: Mid=0x%04X \"%s\"\n", Menu.MenuId, Menu.Text)
    Phase = PH_WAIT_CMD
    lcd.invalidate()
  end
end


local translations = {en="DSM FP v58"}

local function name(widget)
  local locale = system.getLocale()
  return translations[locale] or translations["en"]
end

local function create()
  print("create() called")

  os.mkdir(LOG_PATH)

  local w, h = lcd.getWindowSize()
  if (w > 128 and  h > 64) then
    LCD_W_BUTTONS       = 60
    LCD_H_BUTTONS       = 20
    
    LCD_X_MAX, LCD_Y_MAX  = w, h
    LCD_X_RIGHT_BUTTONS   = LCD_X_MAX - LCD_W_BUTTONS - 1
    
    lcd.font(FONT_STD)
    local tw, th = lcd.getTextSize("")
    LCD_Y_LINE_HEIGHT  = th + 1
    LCD_Y_LOWER_BUTTONS = (8 * LCD_Y_LINE_HEIGHT) + 2
  end
  DSM_Init()
  return {}
end

local function wakeup(widget)
  if (Phase == PH_INIT) then 
    Inc_Init() -- Incremental initialization
  elseif Phase == PH_EXIT_DONE then
      DSM_Release()
      LOG_close()
      system.exit()
  else
    if (SIMULATOR) then
      DSM_Sim_RX() 
    else
      DSM_Send_Receive()
    end
  end
end

local function paint(widget)
  print("paint() called")
  if (Phase == PH_INIT) then 
    Inc_Init_paint()-- Incremental initialization
  else
    DSM_Display()
  end
end

local function event(widget, category, value, x, y)
  print("Event received:", category, value, x, y, KEY_EXIT_BREAK)
  if category == EVT_KEY then
    DSM_HandleEvent(value)
    lcd.invalidate()
  end
  return true
end

local icon = lcd.loadMask("icon.png")

local function init()
  LOG_write("init() called")
  system.registerSystemTool({name=name, icon=icon, create=create, wakeup=wakeup, event=event, paint=paint})
end

return {init=init}

