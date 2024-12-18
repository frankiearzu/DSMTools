---- #########################################################################
---- #                                                                       #
---- # Copyright (C) Frankie Arzu                                            #
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

local arg = {...}

local config = arg[1]
local ui     = arg[2]

local LANGUAGE   <const>  = "en"
local DEBUG_ON   <const>  = true

local I2C_FORWARD_PROG  <const> = 0x09

local LOG_FILE   <const>  = config.logPath .. "dsm_log.txt"
local MSG_FILE   <const>  = config.msgPath .. "msg_fwdp_" .. LANGUAGE .. ".txt"

-- Phase
local PH_INIT <const>  = 0
local PH_RX_VER <const>, PH_TITLE <const>, PH_TX_INFO <const>                   = 1, 2, 3 
local PH_LINES <const>, PH_VALUES <const>                                       = 4, 5
local PH_VAL_CHANGING <const>, PH_VAL_EDITING <const>, PH_VAL_EDIT_END <const>  = 6, 7, 8
local PH_WAIT_CMD <const> , PH_EXIT_REQ <const> , PH_EXIT_DONE <const>          = 9, 10, 11

-- Line Types
local LT_MENU <const>                                           = 0x1C 
local LT_LIST_NC <const>, LT_LIST_NC2 <const>                   = 0x6C, 0x6D 
local LT_LIST <const>, LT_LIST_ORI <const>, LT_LIST_TOG <const> = 0x0C, 0xCC, 0x4C
local LT_VALUE_NC <const>                                       = 0x60
local LT_VALUE_PERCENT <const>, LT_VALUE_DEGREES <const>        = 0xC0, 0xE0 
local LT_VALUE_PREC2 <const>                                    = 0x69

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

local TX_CHANNELS          <const> = 12
local TX_FORWARD_PROG_VER  <const> = 0x15

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
local refreshDisplay      = false
local reportErrorDiag     = false
local reportErrorMsg      = ""

--Channel Types --
local CT_NONE    <const> = 0x00
local CT_AIL     <const> = 0x01
local CT_ELE     <const> = 0x02
local CT_RUD     <const> = 0x04
local CT_REVERSE <const> = 0x20
local CT_THR     <const> = 0x40
local CT_SLAVE   <const> = 0x80

-- Seems like Reverse Mix is complement of the 3 bits
local CMT_NORM     <const> = 0x00   -- 0000
local CMT_AIL      <const> = 0x10   -- 0001 Taileron
local CMT_ELE      <const> = 0x20   -- 0010 For VTIAL and Delta-ELEVON
local CMT_RUD      <const> = 0x30   -- 0011 For VTIAL
local CMT_RUD_REV  <const> = 0x40   -- 0100 For VTIAL
local CMT_ELE_REV  <const> = 0x50   -- 0101 For VTIAL and Delta-ELEVON A
local CMT_AIL_REV  <const> = 0x60   -- 0110 Taileron 
local CMT_NORM_REV <const> = 0x70   -- 0111

local MT_NORMAL    <const>  = 0
local MT_REVERSE   <const>  = 1

local MODEL = {
  modelName = "",            -- The name of the model comming from OTX/ETX
  modelOutputChannel = { [0]=    -- Output information from OTX/ETX
      { min = -100, max = 100 }, -- Ch1
      { min = -100, max = 100 },
      { min = -100, max = 100 },
      { min = -100, max = 100 },
      { min = -100, max = 100 }, -- Ch5
      { min = -100, max = 100 },
      { min = -100, max = 100 },
      { min = -100, max = 100 },
      { min = -100, max = 100 },
      { min = -100, max = 100 },  -- Ch10
  },  

  TX_CH_TEXT= { }, 
  PORT_TEXT = { },

  DSM_ChannelInfo = { [0] =  -- Channel Role/Name info 
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



local M_DB = {}

local WT_A1       <const> = 0
local WT_A2       <const> = 1
local WT_FLPR     <const> = 2
local WT_A1_F1    <const> = 3
local WT_A2_F1    <const> = 4
local WT_A2_F2    <const> = 5
local WT_ELEVON_A <const> = 6
local WT_ELEVON_B <const> = 7


local TT_R1       <const> = 0
local TT_R1_E1    <const> = 1
local TT_R1_E2    <const> = 2
local TT_R2_E1    <const> = 3
local TT_R2_E2    <const> = 4
local TT_VT_A     <const> = 5
local TT_VT_B     <const> = 6
local TT_TLRN_A   <const> = 7
local TT_TLRN_B   <const> = 8
local TT_TLRN_A_R2 <const> = 9
local TT_TLRN_B_R2 <const> = 10

local MV_AIRCRAFT_TYPE <const> = 1001
local MV_WING_TYPE     <const> = 1002
local MV_TAIL_TYPE     <const> = 1003
        
local MV_CH_BASE       <const> = 1010
local MV_CH_THR        <const> = 1010
local MV_CH_L_AIL      <const> = 1011
local MV_CH_R_AIL      <const> = 1012
local MV_CH_L_FLP      <const> = 1013
local MV_CH_R_FLP      <const> = 1014

local MV_CH_L_RUD      <const> = 1015
local MV_CH_R_RUD      <const> = 1016
local MV_CH_L_ELE      <const> = 1017
local MV_CH_R_ELE      <const> = 1018

local MV_PORT_BASE     <const> = 1020
local MV_DATA_END      <const> = 1040


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
  if (line.TextId == 0x00CD) then return true end   -- Exceptiom: Level model and capture attitude
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
  local text = Text[index]
  local out = nil

  if (text == nil) then
    out = string.format("Unknown_%X", index) 
  else
    out = text
  end

  if (index >= 0x5000) then -- Image
    out = ""
  end 

  if (index >= 0x8000) then -- Flight Mode
    out = Flight_Mode [index - 0x8000]
  end 

  return out
end

local function Get_Text_Value(index)
  local out = getTxChText(index)
  if (out) then return out end

  local text = List_Text[index]
  if (text == nil) then
    out = Get_Text(index)
  else
    out = text
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
  if (not config.simulation) then
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
  local out = { 0x70 + #arg } -- Header: length + 0x70

  local hex = string.format("%02X ",out[1])
  local len = #arg
  if (len < 6) then len = 6 end -- Always 6 bytes

  for i = 1, len do
      hex = hex .. string.format("%02X ",arg[i] or 0)
      out[i+1] = arg[i] or 0
  end

  --LOG_write("TX:Sending (hex)  %s\n",hex)

  multiSensor:pushFrame(out)
end
---------------------

local function ChangePhase(newPhase)
  --print("Change Phase ", newPhase)
  Phase = newPhase
  SendDataToRX = 1
end

local function Value_Add(dir)
  local line = MenuLines[ctx_SelLine]
  local origVal = line.Val
  local inc = dir

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

local function DSM_HandleEvent(event, rotarySpeed)
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
        event = KEY_ENTER_FIRST
      else
        if (Menu.BackId > 0 ) then -- Back??
          ctx_SelLine = -1 --Back Button
          event = KEY_ENTER_FIRST
        else
          ChangePhase(PH_EXIT_REQ)
        end
      end
    end
  end -- Exit

  if Phase == PH_RX_VER then return end -- nothing else to do 

  if event == KEY_ROTARY_RIGHT then  -- NEXT
    if isEditing() then -- Editting?
      Value_Add(1*rotarySpeed)
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
      Value_Add(-1*rotarySpeed)
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
  elseif event == KEY_ENTER_FIRST then -- ENTER
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
      local b0, b1, ChDesc = info[0], info[1], info[2]
      DSM_Send(0x20, 0x06, portNo, portNo, b0,b1)
      LOG_write("TX:DSM_TxInfo_20(Port=#%d, (%02x, %02x) %s)\n", portNo, b0,b1,ChDesc or "")

      if (TX_Info_Type == 0x1F) then -- SmartRx
          TX_Info_Step = 1
      elseif (TX_Info_Type == 0x00) then -- AR636
          TX_Info_Step = 2
      end 
  elseif (TX_Info_Step == 1) then
    local info = MODEL.modelOutputChannel[portNo]
    local leftTravel =   math.abs(info.min)
    local rightTravel =  math.abs(info.max)

    DSM_Send(0x23, 0x06, 0x00, leftTravel, 0x00, rightTravel)
    LOG_write("TX:DSM_TxInfo_Travel(Port=#%d,(L=%d - R=%d))\n", portNo,leftTravel,rightTravel)

    TX_Info_Step = 2
  elseif (TX_Info_Step == 2) then
    -- Subtrim 
    local b1,b2,b3,b4 = 0x00, 0x8E, 0x07, 0x72 -- (192-1904)
  
    local info = MODEL.DSM_ChannelInfo[portNo]
    if info[1] == CT_THR or info[1] == CT_NONE then -- Thr and other switches
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
    -- Number of Channels after Ch6 and FP version
    DSM_Send(0x11, 0x06, TX_CHANNELS - 6 , TX_FORWARD_PROG_VER, 0x00, 0x00)
    LOG_write("TX:GetVersion(TX_MAX_CH=%d, TX_FP_FIRMWARE = 0x%02X)\n",TX_CHANNELS, TX_FORWARD_PROG_VER)

  elseif Phase == PH_WAIT_CMD then     -- keep connection open
    DSM_Send(0x00, 0x04, 0x00, 0x00) -- HB
    LOG_write("TX:TxHb\n")

  elseif Phase == PH_TITLE then     -- request menu title
    DSM_Send(0x16, 0x06, menuMSB, menuLSB, 0x00, ctx_SelLine)
    if (menuId == 0x0001) then -- Executed Save&Reset menu
      LOG_write("RX Restart....\n")
      Phase = PH_RX_VER
      ctx_isReset = true
    elseif (menuId == 0x0003) then -- Hard Reset, just exit
      LOG_write("Factory Reset....\n")
      Phase = PH_EXIT_DONE
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
    -- Send number of channels after Ch6 and FP Version
    DSM_Send(0x12, 0x06, TX_CHANNELS-6, TX_FORWARD_PROG_VER)
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

local function DSM_ReadMultiBuffer()
  if (SendDataToRX==1) then  -- Sending??.
    return
  end

  local data =  multiSensor:popFrame({i2cAddress=I2C_FORWARD_PROG})
  
  -- move to _multiBuffer
  if (data) then
    for i=1,16 do  -- Copy from 1 based array into array starting at Pos 10
      _multiBuffer[9+i] = data[i+3] or 0xFF
    end
  end
end

local function DSM_Send_Receive()
  DSM_ReadMultiBuffer()

  --  Receive part: Process incoming messages if there is nothing to send 
  if SendDataToRX==0 and multiBuffer(10) == I2C_FORWARD_PROG  then
    local cmd = DSM_ProcessResponse()
    -- Data processed
    multiBuffer(10, 0x00)
    RXInactivityTime = getTime() + 8   -- Reset Inactivity timeout (8s)
    refreshDisplay      = true
  else
    -- Check if enouth time has passed from last Received activity
    if (getTime() > RXInactivityTime and Phase==PH_WAIT_CMD) then
        LOG_write("RX Disconnected!!!\n")
        reportErrorMsg = "RX Disconnected!!!"
        reportErrorDiag = true
        Phase = PH_EXIT_DONE
    end
  end

    -- Sending part --
  if SendDataToRX == 1 then
    SendDataToRX = 0
    DSM_SendRequest()
    refreshDisplay      = true
    TXInactivityTime = getTime() + 1   -- Reset Inactivity timeout (2s)
  else
    -- Check if enouth time has passed from last transmit activity
    if getTime() > TXInactivityTime then
      SendDataToRX = 1   -- Switch to Send mode to send HB
      --LOG_write("Timeout.. Switching to send\n")
      refreshDisplay      = true
    end
  end
end  

-----

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
  ui.clearTouchRegistry()
 

  --Draw RX Menu
  if Phase == PH_RX_VER then
    ui.drawFPSubHeader(0,"DSM Frwd Prog "..config.version)

    local msgId = 0x300 -- Waiting for RX
    if (ctx_isReset) then msgId=0x301 end -- Waiting for Reset
    ui.drawFPSubHeader(ui.getFPLineHeight()*4,Get_Text(msgId))
    return
  end

  if (Phase == PH_TX_INFO) then
    ui.drawFPSubHeader(ui.getFPLineHeight()*4,"Sending CH"..(ctx_CurLine+1))
  end

    -- display RX version
  if (ctx_EditLine == nil) then
    local msg = "DSM Frwd Prog "..config.version.."       " .. RX_Name .. " v" .. RX_Version
    ui.drawFPSubHeader(ui.getFPBottomLineY(),msg)
  end

  if Menu.MenuId == 0 then return end; -- No Title yet

  -- Got a Menu
  ui.drawFPHeader(0, Menu.Text)

  local y = ui.getFPLinesY()

  for i = 0, 6 do
   
    local line = MenuLines[i]

    if line.Text ~= nil then
      local heading = line.Text

      if (line.TextId >= 0x8000) then     -- Flight mode
        heading = GetFlightModeValue(line)
        ui.drawFPFlightMode(y, heading)
      elseif (line.TextId >= 0x5000) then     -- Render Image
        -- Render Image# TextID
        local imageName = string.format("IMG%X.jpg",line.TextId)
        ui.drawBitmap(1,y, imageName)
      elseif (line.Type == LT_MENU) then -- Menu or Sub-Headeer
        if (isSelectable(line)) then
          -- Menu to another menu 
          ui.drawFPMenuLine(y, heading, i, ctx_SelLine) -- display text
        else
          -- Menu lines with no navigation.. Just Sub-Header 
          ui.drawFPSubHeader(y, heading)
        end
      else
        -- Line with Value
        local text = nil
        if line.Val ~= nil then -- Value to display??
          text = line.ValText

          if isListLine(line) then
            local textId = line.Val + line.TextStart
            -- image??
            local offset = 0
            if (line.Type==LT_LIST_ORI) then offset = offset + 0x100 end --FH6250 hack
            local imgDesc = List_Text_Img[textId+offset]
            
            if (imgDesc and i == ctx_SelLine) then        -- Optional Image and Msg for selected value
              ui.drawBitmap(5, ui.getFPLinesY() + 1, imgDesc) -- 2nd line
            end
          end -- ListLine
        end -- Line with value/list
        ui.drawFPValueLine(y, heading, text or "--", i, ctx_SelLine, ctx_EditLine)
      end  -- not Flight mode
    end
    y = y + ui.getFPLineHeight() + ui.getFPLinesHeightPad()
  end     -- for

  if Menu.BackId~=0 then
    ui.drawButton(ui.fp.rightButtonXpos, 0, "Back", -1, ctx_SelLine)
  end

  if (not ctx_EditLine) then
    if Menu.NextId~=0 then
      ui.drawButton(ui.fp.rightButtonXpos, ui.getFPBottomLineY(), "Next", 7, ctx_SelLine)
    end

    if Menu.PrevId~=0 then
      ui.drawButton(1, ui.getFPBottomLineY(), "Prev", 8, ctx_SelLine)
    end
  end

  if (ctx_EditLine) then
    ui.drawEditButtons()
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
    for l=1,30 do -- do 30 lines at a time 
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
            Text[index] =  text
          elseif (type == "LT") then
            List_Text[index] = text
          elseif (type == "LI") then
            List_Text_Img[index] = text
          elseif (type == "FM") then
            Flight_Mode[index-0x8000] = text
          elseif (type == "RX") then
            RxName[index] = text
          else
            assert(false, string.format("%s:%d: Invalid Line Type [%s]", fileName, FileState.lineNo, type))
          end
      end
      --gc()
    end -- for 
    gc()
  end -- if

  return 0
end


local function ReadTxModelData()
  local chNameDef = {[0]="Ail","Ele","Thr","Rud"}

  local TRANSLATE_AETR_TO_TAER=false

  -- Find the multimodule 
  module = model.getModule(0) -- Internal
  if (module and module:enable() and module:type()==15) then
      print("Module(0) is multi-module")
  else
    module = model.getModule(1) -- External 
    if (module and module:enable() and module:type()==15) then
      print("Module(1) is multi-module")
    else
      print("No-MultiModule")
      module = nil
    end
  end

  -- Find the DSM "Disable channel mapping" option 
  if (module) then
    local value = module:option("Disable channel mapping")
    if (value) then
        print("Disable Ch Map  = ",value)
        TRANSLATE_AETR_TO_TAER = (value==0)
    end
  end


  MODEL.modelName = model.name()
  MODEL.modelPath = model.path():gsub(".bin", "") -- remove ".bin"

  print("Name ="..MODEL.modelName)
  print("Path ="..MODEL.modelPath)

  -- Read Info for Ch1 to Ch12
  local i= 0
  for i = 0, TX_CHANNELS-1 do 
      local ch = model.getChannel(i) 
      if (ch~=nil) then
          local cht = { name=ch:name(), min=ch:min(), max=ch:max(), revert=ch:direction()==-1, 
                       offset =ch:center(), ppmCenter=ch:pwmCenter(), symetrical=true }  

          MODEL.modelOutputChannel[i] = cht   -- Table: name, min=-100, max=+100 subtrim=??
          if (string.len(cht.name)==0) then 
              cht.formatCh = string.format("TX:Ch%i",i+1)
          else
              cht.formatCh = string.format("TX:Ch%i/%s",i+1,cht.name or "--")
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
          LOG_write("Port%d %s [%d,%d] Rev=%s, Off=%d, ppmC=%d, syn=%s\n",i+1,MODEL.TX_CH_TEXT[i],ch.min,ch.max, ch.revert, ch.offset, ch.ppmCenter, ch.symetrical)
      end
  end
end

local function channelType2String(byte1, byte2) 
  local s = ""

  if (byte2==0) then return s end;
  
  if ((byte2 & CT_AIL)>0) then s=s.."Ail" end
  if ((byte2 & CT_ELE)>0) then s=s.."Ele" end
  if ((byte2 & CT_RUD)>0) then s=s.."Rud" end
  if ((byte2 & CT_THR)>0) then s=s.."Thr" end

  if ((byte2 & CT_REVERSE)>0) then s=s.."-" end

  if ((byte2 & CT_SLAVE)>0) then s=s.." Slv" end

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
  local wingType = M_DB[MV_WING_TYPE]
  local tailType = M_DB[MV_TAIL_TYPE]

  local thrCh  =  M_DB[MV_CH_THR]
  local lAilCh =  M_DB[MV_CH_L_AIL]
  local rAilCh =  M_DB[MV_CH_R_AIL]

  local lElevCh = M_DB[MV_CH_L_ELE]
  local rElevCh = M_DB[MV_CH_R_ELE]

  local lRudCh = M_DB[MV_CH_L_RUD]
  local rRudCh = M_DB[MV_CH_R_RUD]

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
      if (M_DB[MV_PORT_BASE+i]==MT_REVERSE and DSM_Ch[i][1]>0) then
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

-----------------------------------------------------------------------------------------------------------
local initStep=0
local FileState = { lineNo=0 }

local function Inc_Init_paint()
  ui.drawFPSubHeader(0,"Loading Msg file: "..(FileState.lineNo or 0))
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

------------------------------------------------------------------------------------------------------------
-- Init

local function ST_LoadFileData() 
  local fname = MODEL.modelPath .. ".txt"
 
   -- Clear Menu Data
   for i = 0, MV_DATA_END do
       M_DB[i]=nil
   end
 
   print("Loading File:"..fname)
 
   local file = io.open(config.dataPath.. fname, "r")  -- read File 
   -- cannot read file???
   if (file==nil) then return 0 end
 
   local line = file:read(5000)
   file:close()
 
   if line==nil or #line == 0 then return 0 end -- No data??
 
   -- Process the input, each line is "Var_Id : Value" format 
   -- Store it into MANU_DATA
   local i=0
   for k, v in string.gmatch(line, "(%d+):(%d+)") do
       --print("Read ",k," = ", v)
       M_DB[k+0]=v+0 -- do aritmentic to convert string to number
       i=i+1
   end
 
   -- Return 0 if no lines processed, 1 otherwise
   if (i > 0) then return 1 else return 0 end
end

local function DSM_Init()
  LOG_open()
  LOG_write("--- NEW SESSION\n")

  --DSM_Init_Model()

  Phase = PH_INIT
  initStep=0
  FileState = { lineNo=0 }
  reportErrorDiag = false

  ReadTxModelData()

  local r = ST_LoadFileData()
  if (r == 1) then
    LOG_write("Creating DSMPort Info\n")
    CreateDSMPortChannelInfo()
    reportErrorDiag = false
  else
    reportErrorMsg = "Cannot load config file. Configure Plane first"
    reportErrorDiag = true
  end

  --M_DATA = nil
  --MODEL.PORT_TEXT = nil
  gc()
end

------------------------------------------------------------------------------------------------------------

local oldPhase = 0
local sim = nil
local simCallbacks = nil

local function DSM_Sim_RX()
  local function getSimMenu(id)
    if (simCallbacks==nil) then
      simCallbacks = {}
      simCallbacks.Get_Text = Get_Text
      simCallbacks.updateValText = updateValText
      simCallbacks.isListLine = isListLine
    end

    if (sim==nil) then
      print("Loading lib-sim-AR631.lua")
      sim = assert(loadfile(config.libPath.."lib-sim-AR631.lua"))(simCallbacks)
    end
    
    local newData = sim.AR631_getMenu(id, simCallbacks)

    Menu        = newData.Menu
    MenuLines   = newData.MenuLines
    ctx_CurLine = newData.ctx_CurLine
    ctx_SelLine = newData.ctx_SelLine
  end



  if (oldPhase~=Phase) then
    --print("SimRX", Phase)
    oldPhase = Phase
  end

  if (Phase==PH_EXIT_REQ) then
    config.exit()
  end
  if (Phase == PH_RX_VER) then
    RX_Name = Get_RxName(0x16)
    RX_Version = "1.2.sim"
    Menu.MenuId = 0
    Phase = PH_TITLE
    LOG_write("Sim-RX:Version: %s %s\n", RX_Name, RX_Version)
  elseif (Phase == PH_TITLE) then
    getSimMenu(Menu.MenuId)
    LOG_write("Sim-RX:Menu: Mid=0x%04X \"%s\"\n", Menu.MenuId, Menu.Text)
    Phase = PH_WAIT_CMD
    refreshDisplay = true
  end
end

local function create()
  print("FwdProg.create() called")
  DSM_Init()

  lcd.setWindowTitle("Fwd Prog")

    -- REMOVE when bug is fixed about rotary 
  local w,h = ui.getWindowSize()
  form.clear()
  form.addTextButton(nil, {x=w-2,y=h-2,w=2,h=2}, "XXX", function()  end)

  return {}
end

local function close()
  print("FwdProg.close() called")
  DSM_Release()
  LOG_close()
end

local errorReported = 0
local function wakeup(widget)
  if (reportErrorDiag) then
    if (errorReported < 60) then
      lcd.invalidate()
      errorReported=errorReported + 1
    else
      errorReported = 0
      reportErrorDiag = false
      Phase = PH_EXIT_DONE
    end
    return    
  end

  if (Phase == PH_INIT) then 
    Inc_Init() -- Incremental initialization
  elseif Phase == PH_EXIT_DONE then
    close()
    config.exit()
  else
    if (config.simulation) then
      DSM_Sim_RX() 
    else
      DSM_Send_Receive()
    end
    if (refreshDisplay) then
      lcd.invalidate()
      refreshDisplay=false
    end
  end
end

local function paint(widget)
  --print("paint() called")
  if (reportErrorDiag) then
    ui.drawFPSubHeader(0,reportErrorMsg)
  elseif (Phase == PH_INIT) then 
    Inc_Init_paint()-- Incremental initialization
  else
    DSM_Display()
  end
end

local function event(widget, category, value, x, y)
  --print("Event received:", category, value, x, y)
  if category == EVT_KEY then
    DSM_HandleEvent(value,x)
    refreshDisplay=true
  elseif category == EVT_TOUCH and value==16641 then -- touch release
    -- Convert touch commands to equivalent KEYs
    local line = ui.touchToButtonValue(x,y)
    if (line) then
      if (isEditing()) then
          local keyValue, rotarySpeed = ui.editValueToKeyEvent(line)
          if (keyValue) then
            DSM_HandleEvent(keyValue, rotarySpeed)
            refreshDisplay=true
          end
      else
          ctx_SelLine = line
          DSM_HandleEvent(KEY_ENTER_FIRST, 1)
          refreshDisplay=true
          return false
      end -- if ctx_Editline
    end -- if line
  end
  return true
end

return {create=create, close=close, wakeup=wakeup, event=event, paint=paint}

