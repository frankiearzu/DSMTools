local toolName = "TNS|DSM Frwd Prog v0.59b (MIN)|TNE"

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


local VERSION             = "v2.0"
local LANGUAGE            = "en"
local DSMLIB_PATH         = "/SCRIPTS/TOOLS/dsm-tools-min/"
local DEBUG_ON            = 1

local LOG_FILE            = "/LOGS/dsm_min_log.txt"
local MSG_FILE            = DSMLIB_PATH.."i18n/msg_fwdp_" .. LANGUAGE .. ".txt"
local MSG_FILE_MIN        = DSMLIB_PATH.."i18n/MIN_msg_fwdp_" .. LANGUAGE .. ".txt"
local MSG_MIN_FILE_OFFSET = 20000

-- Phase
local PH_INIT = 0
local PH_RX_VER, PH_GET_MENU, PH_TX_INFO                   = 1, 2, 3
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
local Flight_Mode         = {[0]="Fligh Mode %s", "Flight Mode %s", "Gyro Sys %s / Flight Mode %s"}
local RxName              = {}

local TXInactivityTime    = 0
local RXInactivityTime    = 0
local TX_Info_Step        = 0
local TX_Info_Type        = 0
local Change_Step         = 0
local originalValue       = 0

local TX_MAX_CH           = 12 - 6 -- Number of Channels after Ch6
local TX_FIRMWARE_VER     = 0x15

--local ctx = {
local  ctx_SelLine = 0      -- Current Selected Line
local  ctx_EditLine = nil   -- Current Editing Line
local  ctx_CurLine = -1     -- Current Line Requested/Parsed via h message protocol
local  ctx_isReset = false   -- false when starting from scracts, true when starting from Reset
--}

local MODEL = {
  modelName = "",            -- The name of the model comming from OTX/ETX
  modelOutputChannel = {},   -- Output information from OTX/ETX

  TX_CH_TEXT= { }, 
  PORT_TEXT = { },

  DSM_ChannelInfo = {}       -- Data Created by DSM Configuration Script
}

local Menu                = { MenuId = 0, Text = "", TextId = 0, PrevId = 0, NextId = 0, BackId = 0 }
local MenuLines           = {}
local RX_Name             = ""
local RX_Version          = ""

local logFile             = nil

--local LCD_X_LINE_TITLE    = 0
--local LCD_X_LINE_VALUE    = 75

local LCD_W_BUTTONS       = 19
local LCD_H_BUTTONS       = 10

local LCD_X_MAX           = 128
local LCD_X_RIGHT_BUTTONS = LCD_X_MAX - LCD_W_BUTTONS - 1

local LCD_Y_LINE_HEIGHT   = 7
local LCD_Y_LOWER_BUTTONS = (8 * LCD_Y_LINE_HEIGHT) + 2

local TEXT_ATTR           = SMLSIZE

local function gc()
  collectgarbage("collect")
end

local function LOG_open()
  if (DEBUG_ON == 0) then return end
  logFile = io.open(LOG_FILE, "w")   -- Truncate Log File
end

local function LOG_write(...)
  if (DEBUG_ON == 0) then return end
  if (logFile == nil) then LOG_open() end
  local str = string.format(...)
  io.write(logFile, str)
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
  local r, x = bit32.band(number, 0xFF)
  return r
end

local function int16_MSB(number) -- Most signifcant byte
  return bit32.rshift(number, 8)
end

local function Dsm_to_Int16(lsb, msb) -- Componse an Int16 value
  return bit32.lshift(msb, 8) + lsb
end

local function Dsm_to_SInt16(lsb, msb) -- Componse a SIGNED Int16 value
  local value = bit32.lshift(msb, 8) + lsb
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
  local f=MSG_FILE
  if (pos >= MSG_MIN_FILE_OFFSET) then  -- Depending on offset, use the main, or MIN version
    f = MSG_FILE_MIN
    pos = pos - MSG_MIN_FILE_OFFSET
  end

  -- open and read File
  local dataFile = io.open(f, "r")   
  io.seek(dataFile,pos)
  local buff = io.read(dataFile, 100)
  io.close(dataFile)

  local line=""
  local index=""
  local type=""

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
  gc()
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
  --Init TX buffer
  multiBuffer(3, 0x00)
  --Init RX buffer
  multiBuffer(10, 0x00)
  --Init telemetry
  multiBuffer(0, string.byte('D'))
  multiBuffer(1, string.byte('S'))
  multiBuffer(2, string.byte('M'))
end

local function DSM_Release()
  multiBuffer(0, 0)
end
--------------------
local function DSM_Send(...)
  local arg = { ... }
  for i = 1, #arg do
    multiBuffer(3 + i, arg[i])
  end
  multiBuffer(3, 0x70 + #arg)

  TXInactivityTime = getTime() + 200
end
---------------------

local function ChangePhase(newPhase)
  Phase = newPhase
  SendDataToRX = 1
end

local function Value_Add(dir)
  local line = MenuLines[ctx_SelLine]
  local origVal = line.Val
  local inc = dir

  if (not isListLine(line)) then -- List do slow inc 
    local Speed = getRotEncSpeed()
    if Speed == ROTENC_MIDSPEED then
      inc = (5 * dir)
    elseif Speed == ROTENC_HIGHSPEED then
      inc = (15 * dir)
    end
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
  ChangePhase(PH_GET_MENU)
end

local function DSM_HandleEvent(event)
  if event == EVT_VIRTUAL_EXIT then
    --if Phase == PH_RX_VER then
    --  Phase = PH_EXIT_DONE -- Exit program
    --else
      if isEditing() then   -- Editing a Line, need to  restore original value
        MenuLines[ctx_EditLine].Val = originalValue
        event = EVT_VIRTUAL_ENTER
      else
        if (Menu.BackId > 0 ) then -- Back??
          ctx_SelLine = -1 --Back Button
          event = EVT_VIRTUAL_ENTER
        else
          ChangePhase(PH_EXIT_REQ)
        end
      end
    --end
  end -- Exit

  if Phase == PH_RX_VER then return end -- nothing else to do 

  if event == EVT_VIRTUAL_NEXT then
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
  
  if event == EVT_VIRTUAL_PREV then
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
  elseif event == EVT_VIRTUAL_ENTER then
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
    --LOG_write("TX:TxHb\n")

  elseif Phase == PH_GET_MENU then     -- request menu title
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
      Phase = PH_WAIT_CMD
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
    DSM_Send(0x12, 0x06, TX_MAX_CH, TX_FIRMWARE_VER, 0x00, 0x00)
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


local function DSM_Send_Receive()

  --  Receive part: Process incoming messages if there is nothing to send 
  if SendDataToRX==0 and multiBuffer(10) == 0x09  then
    local cmd = DSM_ProcessResponse()
    -- Data processed
    multiBuffer(10, 0x00)
    RXInactivityTime = getTime() + 800   -- Reset Inactivity timeout (8s)
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
    TXInactivityTime = getTime() + 200
  else
    -- Check if enouth time has passed from last transmit activity
    if getTime() > TXInactivityTime then
      SendDataToRX = 1   -- Switch to Send mode to send HB
    end
  end
end

-----

local function showBitmap(x, y, imgDesc)
  local f = string.gmatch(imgDesc, '([^%|]+)')   -- Iterator over values split by '|'
  local imgName, imgMsg = f(), f()

  f = string.gmatch(imgMsg or "", '([^%:]+)')   -- Iterator over values split by ':'
  local p1, p2 = f(), f()

  lcd.drawText(x, y, p1 or "", TEXT_ATTR)                     -- Alternate Image MSG
  lcd.drawText(x, y + LCD_Y_LINE_HEIGHT, p2 or "", TEXT_ATTR) -- Alternate Image MSG
end


local function drawButton(x, y, text, active)
  local attr = TEXT_ATTR
  if (active) then attr = attr + INVERS end
  lcd.drawText(x, y, text, attr)
end

function GetFlightModeValue(line)
  local ret = line.Text
  local val = line.Val

  if (val==nil) then return string.format(ret,"-","-") end

  local gyroNum = bit32.rshift(val,8)
  local fmNum =   bit32.band(val,0xFF)
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

local ver_rx_count = 0

local function DSM_Display()
  lcd.clear()
  --Draw RX Menu
  if Phase == PH_RX_VER then
    lcd.drawText(1, 0, "DSM Frwd Prog "..VERSION, INVERS)

    local msgId = 0x300 -- Waiting for RX
    if (ctx_isReset) then msgId=0x301 end -- Waiting for Reset
    lcd.drawText(1, 3 * LCD_Y_LINE_HEIGHT, Get_Text(msgId), BLINK) 
    return
  end

    -- display Program version or RX version
  local msg = RX_Name .. " v" .. RX_Version
  ver_rx_count = ver_rx_count + 1
  if (ver_rx_count > 50) then
      msg = "FProg "..VERSION
      if (ver_rx_count > 100) then ver_rx_count=0 end
  end
  lcd.drawText(40, LCD_Y_LOWER_BUTTONS, msg, TEXT_ATTR) 

  if Menu.MenuId == 0 then return end; -- No Title yet

  -- Got a Menu
  lcd.drawText(1, 0, Menu.Text, TEXT_ATTR + INVERS)

  if (Phase == PH_TX_INFO) then
    lcd.drawText(1, 3 * LCD_Y_LINE_HEIGHT, "Sending CH"..(ctx_CurLine+1), TEXT_ATTR) 
  end

  local y = LCD_Y_LINE_HEIGHT + 2
  for i = 0, 6 do
    local attrib = TEXT_ATTR
    if (i == ctx_SelLine) then attrib = attrib + INVERS end     -- Selected Line

    local line = MenuLines[i]

    if line.Text ~= nil then
      local heading = line.Text

      if (line.TextId >= 0x8000) then     -- Flight mode
        heading = GetFlightModeValue(line)
        lcd.drawText(LCD_W / 2, y, heading, attrib + CENTER)
      elseif (line.TextId >= 0x5000) then     -- Render Image
        -- Render Image# TextID-0x5000
      else
        local text = nil
        if line.Type == LT_MENU then       
          local x = 1
          if (not isSelectable(line)) then -- Header only
            x = LCD_W / 2 
            attrib = attrib + CENTER  
          end
          lcd.drawText(x, y, heading, attrib) -- Menu navigation
        else -- list/value
          if line.Val ~= nil then -- Value to display??
            -- text = line.Val
            text = line.ValText

            if isListLine(line) then
              local textId = line.Val + line.TextStart
              --text = Get_Text_Value(textId)

              -- image??
              local offset = 0
              if (line.Type==LT_LIST_ORI) then offset = offset + 0x100 end --FH6250 hack
              local imgDesc = GetTextFromFile(List_Text_Img[textId+offset])
             
              if (imgDesc and i == ctx_SelLine) then             -- Optional Image and Msg for selected value
                showBitmap(1, 20, imgDesc)
              end
            end
          end -- Value 

          if (ctx_EditLine == i) then  -- Editing a Line
            attrib = BLINK + INVERS + TEXT_ATTR
          end
          lcd.drawText(LCD_X_MAX, y, text or "--", attrib + RIGHT) -- display value
          attrib = TEXT_ATTR
          lcd.drawText(1, y, heading, attrib) -- display text        
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

------------------------------------------------------------------------------------------------------------
-- Init
local function DSM_Init()
  --LOG_open()
  --LOG_write("--- NEW SESSION\n")

  --DSM_Init_Model()

  --Set protocol to talk to
  multiBuffer(0, string.byte('D'))
  --test if value has been written
  if multiBuffer(0) ~= string.byte('D') then
    error("Not enough memory!")
    return 2
  end

  if (LCD_W > 128 and  LCD_H > 64) then
    TEXT_ATTR = 0
    LCD_Y_LINE_HEIGHT = 25
    LCD_X_MAX         = 300
    LCD_X_RIGHT_BUTTONS = LCD_X_MAX - 30

    LCD_Y_LOWER_BUTTONS = (8 * LCD_Y_LINE_HEIGHT) + 2
  end

  Phase = PH_INIT
end


-----------------------------------------------------------------------------------------------------------
local initStep=0
local FileState = { lineNo=0 }

local function Inc_Init()
  lcd.clear()
 
  lcd.drawText(1, 0, "Loading Msg file: "..(FileState.lineNo or 0))
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

------------------------------------------------------------------------------------------------------------
-- Main

local function DSM_Run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  end

  if (Phase == PH_INIT) then 
    Inc_Init() -- Incremental initialization
    return 0
  end

  DSM_Display()
  DSM_HandleEvent(event)
  DSM_Send_Receive()
  gc()

  if Phase == PH_EXIT_DONE then
    DSM_Release()
    LOG_close()
    return 2
  else
    return 0
  end
end

---
  gc()
  local M_DATA = {}

  -- Load Model Configuration
  local r = assert(loadScript(DSMLIB_PATH.."apps/DsmMIN_P1.lua"), "Mising: DsmMIN_P1.lua")
                   (MODEL, M_DATA, LOG_write)
  gc()
  if (r==1) then
    -- Translate model Configuration to DSMDATA
    local r = assert(loadScript(DSMLIB_PATH.."apps/DsmMIN_P2.lua"), "Missing: DsmMIN_P2.lua")
                    (MODEL, M_DATA, LOG_write)
  
    MODEL.PORT_TEXT = nil
    --MODEL.TX_CH_TEXT = {}
    gc() 
  else
    error("Cannot load Model Config")
  end
  M_DATA = nil
  gc()
---

return { init = DSM_Init, run = DSM_Run }
