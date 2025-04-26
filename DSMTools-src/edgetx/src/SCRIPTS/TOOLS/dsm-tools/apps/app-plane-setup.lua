---- #########################################################################
---- #                                                                       #
---- # Copyright (C) Frankie Arzu                                            #
-----#                                                                       #
---- # License GPLv2: http:/www.gnu.org/licenses/gpl-2.0.html               #
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
local form   = arg[3]

local LOG_FILE_NAME     = "setup_log.txt"

-- Phase
local PH_INIT  = 0
local PH_RX_VER , PH_GET_MENU  = 1, 2
local PH_VAL_EDITING , PH_VAL_EDIT_END  =  7, 8
local PH_WAIT_CMD , PH_EXIT_REQ , PH_EXIT_DONE  = 9, 10, 11

-- Line Types
local LT_MENU , LT_LIST_NC  = 0x1C, 0x6C

local Phase               = PH_INIT

local Text                = {}
local List_Text           = {}
local List_Text_Img       = {}

local originalValue       = 0

local  ctx_SelLine = 0      -- Current Selected Line
local  ctx_EditLine = nil   -- Current Editing Line

local Menu                = { MenuId = 0, Text = "", TextId = 0, PrevId = 0, NextId = 0, BackId = 0 }
local MenuLines           = {}
local refreshDisplay      = false

local logFile             = nil

local TX_CHANNELS  = 12

local AT_PLANE   = 0

local aircraft_type_text  = {
    [0]="Plane","Heli","Glider","Drone"}

local WT_A1        = 0
local WT_A2        = 1
local WT_FLPR      = 2
local WT_A1_F1     = 3
local WT_A2_F1     = 4
local WT_A2_F2     = 5
local WT_ELEVON_A  = 6
local WT_ELEVON_B  = 7

local wing_type_text  = {
  [0]="Normal","Dual Ail","Flapperon", "Ail + Flp","Dual Ail + Flp","Dual Ail/Flp","Elevon A","Elevon B"}

local TT_R1      = 0
local TT_R1_E1   = 1
local TT_R1_E2   = 2
local TT_R2_E1   = 3
local TT_R2_E2   = 4
local TT_VT_A    = 5
local TT_VT_B    = 6
local TT_TLRN_A  = 7
local TT_TLRN_B  = 8
local TT_TLRN_A_R2  = 9
local TT_TLRN_B_R2  = 10

local tail_type_text = {[0]="Rud Only","Normal","Rud + Dual Ele","Dual Rud + Elv","Dual Rud/Ele",
                         "VTail A","VTail B","Taileron A","Taileron B", 
                         "Taileron A + Dual Rud","Taileron B + Dual Rud"
                        }

local MT_NORMAL    = 0
local MT_REVERSE   = 1

local P1  = 0
local P2  = 1
local P3  = 2
local P4  = 3
local P5  = 4
local P6  = 5
local P7  = 6
local P8  = 7
--local P9 = 8
--local P10 = 9

local MV_AIRCRAFT_TYPE  = 1001
local MV_WING_TYPE      = 1002
local MV_TAIL_TYPE      = 1003
        
local MV_CH_BASE        = 1010
local MV_CH_THR         = 1010

local MV_CH_L_AIL       = 1011
local MV_CH_R_AIL       = 1012
local MV_CH_L_FLP       = 1013
local MV_CH_R_FLP       = 1014

local MV_CH_L_RUD       = 1015
local MV_CH_R_RUD       = 1016
local MV_CH_L_ELE       = 1017
local MV_CH_R_ELE       = 1018

local MV_PORT_BASE      = 1020
local MV_P1_MODE        = 1020
--local MV_P2_MODE      = 1021
--local MV_P3_MODE      = 1022
--local MV_P4_MODE      = 1023
--local MV_P5_MODE      = 1024
local MV_P6_MODE        = 1025
--local MV_P7_MODE      = 1026
--local MV_P8_MODE      = 1027
--local MV_P9_MODE      = 1028
--local MV_P10_MODE     = 1029

local MV_DATA_END       = 1040

-- MENU DATA Management
local M_DB = {}            -- Store the variables used in the Menus.

local lastGoodMenu=0      
  
local currATyp = -1    
local currTTyp = -1
local currWTyp = -1

local menuDataChanged = false
local startTime = getTime()

local MODEL = {
  modelName = "",            -- The name of the model comming from OTX/ETX
  modelPath = "",
  modelOutputChannel = {},   -- Output information from OTX/ETX

  TX_CH_TEXT= { }, 
  PORT_TEXT = { },

  DSM_ChannelInfo = {}       -- Data Created by DSM Configuration Script
}

---------------------------------------------------------------------------------------------------

local function gc()
  collectgarbage("collect")
end

local function LOG_open()
  logFile = assert(io.open("/LOGS/"..LOG_FILE_NAME, "w"))   -- Truncate Log File
end

local function LOG_write(...)
  if (logFile == nil) then LOG_open() end
  local str = string.format("%s :",(getTime()-startTime)) .. string.format(...)
  io.write(logFile, str)
  print(str)
end

local function LOG_close()
  if (logFile ~= nil) then io.close(logFile); logFile = nil end
end

-- Saves MENU_DATA to a file
local function ST_SaveFileData() 
  local fname = MODEL.modelPath

  print("Saving Data:",fname)
  local file = assert(io.open(config.dataPath .. fname, "w"),"Cannot create "..config.dataPath .. fname)  -- write File 
  
  -- Foreach MENU_DATA with a value write Var_Id:Value into file
  for i = 0, MV_DATA_END do
      if (M_DB[i]~=nil) then
          local s = string.format("%s:%s\n",i,M_DB[i])
          io.write(file,s)
      end
  end
  io.close(file)
end

local function ST_LoadFileData() 
   local fname = MODEL.modelPath 
  
    -- Clear Menu Data
    for i = 0, MV_DATA_END do
        M_DB[i]=nil
    end
  
    print("Loading File:"..fname)
  
    local file = io.open(config.dataPath .. fname, "r")  -- read File 
    -- cannot read file???
    if (file==nil) then return 0 end
  
    local line = io.read(file,2000)
    io.close(file)
  
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

local function tailTypeCompatible(a,b)

  local function normalize(tt)
    if (tt==TT_TLRN_A or tt==TT_TLRN_B) then 
      return TT_TLRN_A
    elseif (tt==TT_TLRN_A_R2 or tt==TT_TLRN_B_R2) then
      return TT_TLRN_A_R2
    elseif (tt==TT_VT_A or tt==TT_VT_B) then
      return TT_VT_A
    else
      return tt
    end
  end

  return (normalize(a)==normalize(b))
end

local function ST_PlaneWingInit(wingType) 
    --print("Change Plane WingType:"..wing_type_text[wingType])

    M_DB[MV_WING_TYPE] = wingType

    -- Clear all Wing Data 
    M_DB[MV_CH_L_AIL] = nil
    M_DB[MV_CH_R_AIL] = nil
    M_DB[MV_CH_L_FLP] = nil
    M_DB[MV_CH_R_FLP] = nil

    M_DB[MV_CH_THR] = P1
    
    -- Default Channel Assisgments for each Wing type

    if (wingType==WT_A1) then
        M_DB[MV_CH_L_AIL] = P2
    elseif (wingType==WT_A2 or wingType==WT_FLPR) then
        M_DB[MV_CH_L_AIL] = P6
        M_DB[MV_CH_R_AIL] = P2
    elseif (wingType==WT_A1_F1) then
        M_DB[MV_CH_L_AIL] = P2
        M_DB[MV_CH_L_FLP] = P6
    elseif (wingType==WT_A2_F1) then
        M_DB[MV_CH_L_AIL] = P6
        M_DB[MV_CH_R_AIL] = P2
        M_DB[MV_CH_L_FLP] = P5
    elseif (wingType==WT_A2_F2) then
        M_DB[MV_CH_L_AIL] = P6
        M_DB[MV_CH_R_AIL] = P2
        M_DB[MV_CH_R_FLP] = P5
        M_DB[MV_CH_L_FLP] = P7
    elseif (wingType==WT_ELEVON_A) then
        M_DB[MV_CH_L_AIL] = P2
        M_DB[MV_CH_R_AIL] = P3
    elseif (wingType==WT_ELEVON_B) then
        M_DB[MV_CH_L_AIL] = P3
        M_DB[MV_CH_R_AIL] = P2
    else -- Assume normal 
       print("ERROR: Invalid Wing Type")
    end 
end

local function ST_PlaneTailInit(tailType) 
    if (M_DB[MV_WING_TYPE]==WT_ELEVON_A or
        M_DB[MV_WING_TYPE]==WT_ELEVON_B) then
        tailType = TT_R1 -- Delta only have ruder  
    end

    --print("Change Plane Tail Type:"..tail_type_text[tailType])

    -- Clear all data for Tail 
    M_DB[MV_TAIL_TYPE] = tailType
    M_DB[MV_CH_L_ELE] = nil
    M_DB[MV_CH_R_ELE] = nil
    M_DB[MV_CH_L_RUD] = nil
    M_DB[MV_CH_R_RUD] = nil

    -- Setup Channels for different Tail types 
    if (tailType == TT_R1) then
        M_DB[MV_CH_L_RUD] = P4
    elseif (tailType == TT_R1_E1) then
        M_DB[MV_CH_L_ELE] = P3
        M_DB[MV_CH_L_RUD] = P4
    elseif (tailType == TT_R1_E2) then
        M_DB[MV_CH_L_ELE] = P5
        M_DB[MV_CH_R_ELE] = P3
        M_DB[MV_CH_L_RUD] = P4
    elseif (tailType == TT_R2_E1) then
        M_DB[MV_CH_L_ELE] = P3
        M_DB[MV_CH_L_RUD] = P4
        M_DB[MV_CH_R_RUD] = P5
    elseif (tailType == TT_R2_E2) then
        M_DB[MV_CH_L_ELE] = P5
        M_DB[MV_CH_R_ELE] = P3
        M_DB[MV_CH_L_RUD] = P4
        M_DB[MV_CH_R_RUD] = P6
    elseif (tailType == TT_VT_A or tailType == TT_VT_B) then
        M_DB[MV_CH_L_ELE] = P3
        M_DB[MV_CH_R_ELE] = P4
    elseif (tailType == TT_TLRN_A or tailType == TT_TLRN_B or
            tailType == TT_TLRN_A_R2 or tailType == TT_TLRN_B_R2) then
        M_DB[MV_CH_L_RUD] = P4
        M_DB[MV_CH_L_ELE] = P5
        M_DB[MV_CH_R_ELE] = P3
    else -- Assume Normal 
        print("ERROR:invalid Tail Type")
    end

    if (tailType == TT_TLRN_A_R2 or tailType == TT_TLRN_B_R2) then
      M_DB[MV_CH_R_RUD] = P8
    end
end

local function ST_AircraftInit(aircraftType)
    M_DB[MV_AIRCRAFT_TYPE] = aircraftType
    ST_PlaneWingInit(WT_A1)
    ST_PlaneTailInit(TT_R1_E1)
end


-- Setup Initial Default Data for the Menus
local function ST_Default_Data()
    ST_AircraftInit(AT_PLANE)

    for i=0,9 do
      M_DB[MV_P1_MODE+i] = MT_NORMAL + MODEL.modelOutputChannel[P1+i].revert
    end
end

local function MenuLinePostProcessing(line)
    line.MenuId = Menu.MenuId

    if line.Type == LT_MENU then
        -- nothing to do on menu entries
        line.Val=nil
    elseif line.Type == LT_LIST_NC then
        -- Normalize Min/Max to be relative to Zero
        line.TextStart = line.Min
        line.Def = line.Def - line.Min -- normalize default value 
        line.Max = line.Max - line.Min -- normalize max index
        line.Min = 0 -- min index
    end
end


local function portUse(p)
  local out = nil 
  if p==M_DB[MV_CH_THR] then out = "Thr"
  elseif p == M_DB[MV_CH_L_AIL] then 
      out=(M_DB[MV_CH_R_AIL] and "Ail_L") or "Ail"
  elseif p == M_DB[MV_CH_R_AIL] then out="Ail_R"
  elseif p == M_DB[MV_CH_L_ELE] then 
      out=(M_DB[MV_CH_R_ELE] and "Ele_L") or "Ele"
  elseif p == M_DB[MV_CH_R_ELE] then out="Ele_R"
  elseif p == M_DB[MV_CH_L_RUD] then 
      out=(M_DB[MV_CH_R_RUD] and "Rud_L") or "Rud"
  elseif p == M_DB[MV_CH_R_RUD] then out="Rud-R"
  elseif p == M_DB[MV_CH_L_FLP] then 
      out=(M_DB[MV_CH_R_FLP] and "Flp_L") or "Flp"
  elseif p == M_DB[MV_CH_R_FLP] then out="Flp_R"
  else
    out = ""
  end
  return out
end

-- Creates the menus to Render with the GUI
local function ST_LoadMenu(menuId)

    local function Header(p)
      return MODEL.PORT_TEXT[p].." "..portUse(p)
    end

    local function generateGyroReverse(menuId, P_BASE, V_BASE)
      for i=0,4 do
        MenuLines[i] = { Type = LT_LIST_NC, Text=Header(P_BASE+i), TextId = 0, ValId = V_BASE+i, Min=45, Max=46, Def=45, Val=M_DB[V_BASE+i] }
      end

      MenuLines[5] = { Type = LT_MENU, Text="Only TAER affects AS3X/SAFE react dir", TextId = 0, ValId = menuId }
      MenuLines[6] = { Type = LT_MENU, Text="If changes, RX 'Relearn Servo'", TextId = 0, ValId = menuId }

      ctx_SelLine = 0
    end

    -- Begin
    for i = 0, 6 do -- clear menu
        MenuLines[i] = { MenuId = 0, lineNum = 0, Type = 0 }
    end

    
    if (menuId==0x1000) then -- MAIN MENU
        Menu = { MenuId = 0x1000, Text = "Save-Exit ("..MODEL.modelName..")", PrevId = 0, NextId = 0, BackId = 0, TextId=0 }
       
        if (true) then
            MenuLines[4] = { Type = LT_MENU, Text="Save Changes", TextId = 0, ValId = 0x1005 }
            MenuLines[5] = { Type = LT_MENU, Text="Discard Changes", TextId = 0, ValId = 0xFFF9 }
            ctx_SelLine = 4 
        end
        lastGoodMenu = menuId
    elseif (menuId==0x1001) then -- MODEL SETUP
        local backId = 0xFFF9 -- No changes, just exit
        local title  =  "Setup  ("..MODEL.modelName..")"
        if (menuDataChanged) then
            backId = 0x1000  -- Go to Save menu
            title = title.." *"
        end
        Menu = { MenuId = 0x1001, Text = title, PrevId = 0, NextId = 0, BackId = backId, TextId=0 }
        MenuLines[0] = { Type = LT_MENU, Text = "Aircraft Setup", ValId = 0x1010,TextId=0 }
        MenuLines[1] = { Type = LT_MENU, Text = "Wing & Tail Channels ", ValId = 0x1020, TextId=0 } 
        MenuLines[3] = { Type = LT_MENU, Text = "Gyro Channel Reverse", ValId = 0x1030, TextId=0 } 
        MenuLines[5] = { Type = LT_MENU, Text = "WARNING: Changing of Aircraft", ValId = 0x1001, TextId=0 } 
        MenuLines[6] = { Type = LT_MENU, Text = "deletes prev Ch/Port assgmt.", ValId = 0x1001, TextId=0 } 

        ctx_SelLine = 0
        lastGoodMenu = menuId
    elseif (menuId==0x1005) then
        ST_SaveFileData()
        menuDataChanged = false

        local msg1 = "Data saved to" 
        local msg2 = config.dataPath..MODEL.modelPath

        Menu = { MenuId = 0x1005, Text = "Config Saved", PrevId = 0, NextId = 0, BackId = 0, TextId=0 }
        MenuLines[2] = { Type = LT_MENU, Text=msg1, TextId = 0, ValId = 0x1005 }
        MenuLines[3] = { Type = LT_MENU, Text=msg2, TextId = 0, ValId = 0x1005 }
        MenuLines[6] = { Type = LT_MENU, Text="Complete", TextId = 0, ValId = 0xFFF9 }
        ctx_SelLine = 6
        lastGoodMenu = menuId
    elseif (menuId==0x1010) then
        Menu = { MenuId = 0x1010, Text = "Aircraft", PrevId = 0, NextId = 0x1011, BackId = 0x1001, TextId=0 }
        MenuLines[5] = { Type = LT_LIST_NC, Text="Aircraft Type", TextId = 0, ValId = MV_AIRCRAFT_TYPE, Min=15, Max=15, Def=15, Val=M_DB[MV_AIRCRAFT_TYPE] }
        ctx_SelLine = 5
        lastGoodMenu = menuId
    elseif (menuId==0x1011) then
        Menu = { MenuId = 0x1011, Text = "Model Type: "..aircraft_type_text[currATyp], PrevId = 0, NextId = 0x1020, BackId = 0x1010, TextId=0 }
        MenuLines[4] = { Type = LT_LIST_NC, Text="Wing Type", TextId = 0, ValId = MV_WING_TYPE, Min=20, Max=27, Def=20, Val=M_DB[MV_WING_TYPE] }
        MenuLines[5] = { Type = LT_LIST_NC, Text="Tail Type", TextId = 0, ValId = MV_TAIL_TYPE, Min=30, Max=40, Def=30, Val=M_DB[MV_TAIL_TYPE] }
        ctx_SelLine = 4
        lastGoodMenu = menuId
    elseif (menuId==0x1020) then
        ------ WING  SETUP -------
        local thr = M_DB[MV_CH_THR]
        local leftAil = M_DB[MV_CH_L_AIL]
        local rightAil = M_DB[MV_CH_R_AIL]
        local leftFlap = M_DB[MV_CH_L_FLP]
        local rightFlap = M_DB[MV_CH_R_FLP]

        local thrText     = "Thr"
        local leftAilText = "Left Ail"
        local rightAilText = "Right Ail"
        local leftFlapText = "Left Flap"
        local rightFlapText = "Right Flap"

        if (rightAil==nil) then leftAilText = "Aileron" end
        if (rightFlap==nil) then leftFlapText = "Flap" end

        local title = aircraft_type_text[currATyp].."   Wing:"..wing_type_text[currWTyp]

        Menu = { MenuId = 0x1020, Text = title, PrevId = 0, NextId = 0x1021, BackId = 0x1011, TextId=0 }

        MenuLines[0] = { Type = LT_LIST_NC, Text=thrText, TextId = 0, ValId = MV_CH_THR, Min=0, Max=10, Def=0, Val= thr }

        MenuLines[2] = { Type = LT_LIST_NC, Text=leftAilText, TextId = 0, ValId = MV_CH_L_AIL, Min=0, Max=9, Def=0, Val= leftAil }

        if (rightAil) then
            MenuLines[3] = { Type = LT_LIST_NC, Text=rightAilText, TextId = 0, ValId = MV_CH_R_AIL, Min=0, Max=9, Def=0, Val= rightAil }
        end

        if (leftFlap) then
            MenuLines[4] = { Type = LT_LIST_NC, Text=leftFlapText, TextId = 0, ValId = MV_CH_L_FLP, Min=0, Max=9, Def=0, Val= leftFlap }
        end
        if (rightFlap) then
            MenuLines[5] = { Type = LT_LIST_NC, Text=rightFlapText, TextId = 0, ValId = MV_CH_R_FLP, Min=0, Max=9, Def=0, Val= rightFlap }
        end

        ctx_SelLine = 0
        lastGoodMenu = menuId

    elseif (menuId==0x1021) then
        ------ TAIL SETUP -------
        local leftRud = M_DB[MV_CH_L_RUD] 
        local rightRud = M_DB[MV_CH_R_RUD] 
        local leftEle = M_DB[MV_CH_L_ELE]
        local rightEle = M_DB[MV_CH_R_ELE]

        local leftRudText = "Left Rud"
        local rightRudText = "Right Rud"

        local leftElvText = "Left Ele"
        local rightElvText = "Right Ele"

        if (rightRud==nil) then leftRudText = "Rud"  end
        if (rightEle==nil) then leftElvText = "Ele" end

        local title = aircraft_type_text[currATyp].."  Tail:"..tail_type_text[currTTyp]

        Menu = { MenuId = 0x1021, Text = title, PrevId = 0, NextId = 0x1001, BackId = 0x1020, TextId=0 }
        if (leftRud) then
            MenuLines[1] = { Type = LT_LIST_NC, Text=leftRudText, TextId = 0, ValId = MV_CH_L_RUD, Min=0, Max=9, Def=0, Val= leftRud}
        end

        if (rightRud) then
            MenuLines[2] = { Type = LT_LIST_NC, Text=rightRudText, TextId = 0, ValId = MV_CH_R_RUD, Min=0, Max=9, Def=0, Val=rightRud }
        end

        if (leftEle) then
            MenuLines[4] = { Type = LT_LIST_NC, Text=leftElvText, TextId = 0, ValId = MV_CH_L_ELE, Min=0, Max=9, Def=0, Val=leftEle }
        end

        if (rightEle) then
            MenuLines[5] = { Type = LT_LIST_NC, Text=rightElvText, TextId = 0, ValId = MV_CH_R_ELE, Min=0, Max=9, Def=0, Val=rightEle }
        end

        ctx_SelLine = 1
        lastGoodMenu = menuId
   
    elseif (menuId==0x1030) then
        Menu = { MenuId = 0x1030, Text = "Gyro Reverse (Port 1-5)", PrevId = 0, NextId = 0x1031, BackId = 0x1001, TextId=0 }
        generateGyroReverse(menuId,P1,MV_P1_MODE)
        lastGoodMenu = menuId
    elseif (menuId==0x1031) then
        Menu = { MenuId = 0x1031, Text = "Gyro Reverse (Port 6-10)", PrevId = 0x1030, NextId = 0, BackId = 0x1001, TextId=0 }
        generateGyroReverse(menuId,P6,MV_P6_MODE)
        lastGoodMenu = menuId
    elseif (menuId==0xFFF9) then
        Phase  = PH_EXIT_DONE
        return
    else
        Menu = { MenuId = 0x0002, Text = "NOT IMPLEMENTED", TextId = 0, PrevId = 0, NextId = 0, BackId = lastGoodMenu }
        ctx_SelLine = -1 -- BACK BUTTON
    end

    for i = 0, 6 do 
        if (MenuLines[i].Type > 0) then
            MenuLinePostProcessing(MenuLines[i])
        end
    end
    refreshDisplay = true
    gc()
end

-- Inital List and Image Text for this menus
local function ST_Init_Text(rxId) 
    -- Channel Names use the Port Text Retrived from OTX/ETX
    local p = 0

    for i = 0, 9 do List_Text[i] = MODEL.PORT_TEXT[i]  end
    List_Text[10] = "--"

    -- Aircraft Type
    List_Text[15+AT_PLANE]  = "Airplane"; 

    -- Wing Types
    p = 20+WT_A1;    List_Text[p] = "Single Ail";  List_Text_Img[p]  = "wt_1ail.png|Single Aileron" 
    p = 20+WT_A2;    List_Text[p] = "Dual Ail";  List_Text_Img[p]  = "wt_2ail.png|Dual Aileron" 
    p = 20+WT_FLPR;  List_Text[p] = "Flaperon";  List_Text_Img[p]  = "wt_flaperon.png|Flaperon" 
    p = 20+WT_A1_F1; List_Text[p] = "Ail + Flap";  List_Text_Img[p]  = "wt_1ail_1flp.png|Aileron + Flap" 
    p = 20+WT_A2_F1; List_Text[p] = "Dual Ail + Flap";  List_Text_Img[p]  = "wt_2ail_1flp.png|Dual Aileron + Flap" 
    p = 20+WT_A2_F2; List_Text[p] = "Dual Ail + Dual Flap";  List_Text_Img[p]  = "wt_2ail_2flp.png|Dual Aileron + Dual Flap" 
    p = 20+WT_ELEVON_A; List_Text[p] = "Delta A";  List_Text_Img[p]  = "wt_elevon.png|Delta/Elevon A" 
    p = 20+WT_ELEVON_B; List_Text[p] = "Delta B";  List_Text_Img[p]  = "wt_elevon.png|Delta/Elevon B" 

    -- Tail Types
    p = 30+TT_R1;    List_Text[p] = "Rudder Only";  List_Text_Img[p]  = "tt_1rud.png|Rudder Only" 
    p = 30+TT_R1_E1; List_Text[p] = "Rud + Ele";  List_Text_Img[p]  = "tt_1rud_1ele.png|Tail Normal" 
    p = 30+TT_R1_E2; List_Text[p] = "Rud + Dual Ele";  List_Text_Img[p]  = "tt_1rud_2ele.png|Rud + Dual Ele" 
    p = 30+TT_R2_E1; List_Text[p] = "Dual Rud + Ele";  List_Text_Img[p]  = "tt_2rud_1ele.png|Dual Rud + Ele" 
    p = 30+TT_R2_E2; List_Text[p] = "Dual Rud + Dual Ele";  List_Text_Img[p]  = "tt_2rud_2ele.png|Dual Rud + Dual Elev" 
    p = 30+TT_VT_A;  List_Text[p] = "V-Tail A";  List_Text_Img[p]  = "tt_vtail.png|V-Tail A" 
    p = 30+TT_VT_B;  List_Text[p] = "V-Tail B";  List_Text_Img[p]  = "tt_vtail.png|V-Tail B" 
    p = 30+TT_TLRN_A; List_Text[p] = "Taileron A";  List_Text_Img[p]  = "tt_taileron.png|Taileron A" 
    p = 30+TT_TLRN_B; List_Text[p] = "Taileron B";  List_Text_Img[p]  = "tt_taileron.png|Taileron B" 
    p = 30+TT_TLRN_A_R2; List_Text[p] = "Taileron A + 2x Rud";  List_Text_Img[p]  = "tt_taileron2.png|Taileron A + Dual Rud" 
    p = 30+TT_TLRN_B_R2; List_Text[p] = "Taileron B + 2x Rud";  List_Text_Img[p]  = "tt_taileron2.png|Taileron B + Dual Rud" 

    -- Servo Reverse
    List_Text[45+MT_NORMAL]  = "Normal"
    List_Text[45+MT_REVERSE] = "Reverse"
end

-- Initial Setup
local function ST_Init()
    ST_Init_Text(0)
    gc()
 
    -- Setup default Data if no data loaded
    menuDataChanged = false
    if (M_DB[MV_AIRCRAFT_TYPE]==nil) then
      ST_Default_Data()
      menuDataChanged = true
    end

    currATyp = M_DB[MV_AIRCRAFT_TYPE]
    currWTyp = M_DB[MV_WING_TYPE]
    currTTyp = M_DB[MV_TAIL_TYPE]

    Phase = PH_RX_VER
end

----- Line Type

local function isSelectable(line)
  if (line.Type == LT_MENU and line.ValId == line.MenuId) then return false end -- Menu to same page
  if (line.Type ~= LT_MENU and  line.Max == 0) then return false end            -- Read only data line 
  if (line.Type ~= 0 and line.TextId < 0x8000) then return true end          -- Not Flight Mode
  return false;
end

local function isListLine(line) 
  return line.Type==LT_LIST_NC
end

local function isEditing() 
  return  ctx_EditLine ~= nil
end

-----------------------
local function Get_Text(index)
  local out = Text[index] or string.format("Unknown_%X", index)
  return out
end

local function Get_Text_Value(index)
  local out = List_Text[index] or Get_Text(index)
  return out
end

local function ChangePhase(newPhase)
  Phase = newPhase
end

local function Value_Add(dir)
  local line = MenuLines[ctx_SelLine]
  local inc = dir

  line.Val = line.Val + inc

  if line.Val > line.Max then
    line.Val = line.Max
  elseif line.Val < line.Min then
    line.Val = line.Min
  end
end
--------------

local function GotoMenu(menuId, lastSelectedLine)
  Menu.MenuId = menuId
  ctx_SelLine = lastSelectedLine
  ChangePhase(PH_GET_MENU)
end

local function DSM_HandleEvent(event, rotarySpeed)
  if (not rotarySpeed) then rotarySpeed=1 end

  if event == EVT_VIRTUAL_EXIT then
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
  end -- Exit

  if Phase == PH_RX_VER then return end -- nothing else to do 

  if event == EVT_VIRTUAL_NEXT then
    if isEditing() then -- Editting?
      Value_Add(1 * rotarySpeed)
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
      Value_Add(-1 * rotarySpeed)
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
  

  if event == EVT_VIRTUAL_ENTER then
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

local function DSM_Send_Receive()

    if Phase == PH_RX_VER then -- request RX version
        Phase = PH_GET_MENU
        Menu.MenuId = 0x01001
        refreshDisplay = true
    elseif Phase == PH_WAIT_CMD then 
        
    elseif Phase == PH_GET_MENU then -- request menu title
        ST_LoadMenu(Menu.MenuId)
        if (Phase~=PH_EXIT_DONE) then
          Phase = PH_WAIT_CMD
        end
        refreshDisplay = true
    elseif Phase == PH_VAL_EDIT_END then -- send value
        local line = MenuLines[ctx_SelLine] -- Updated Value of SELECTED line
        
        -- Update the menu data from the line
        if (M_DB[line.ValId] ~= line.Val ) then
            M_DB[line.ValId] = line.Val 
            print(string.format("MENU_DATA[%d/%s]=%d",line.ValId,line.Text, line.Val))
            menuDataChanged=true
        end

        -- Did the Wing type change?
        local wt = M_DB[MV_WING_TYPE]
        if (currWTyp ~= wt) then
            currWTyp = wt
            ST_PlaneWingInit(currWTyp)
        
            -- DELTA has only RUDER 
            if (currWTyp==WT_ELEVON_A or currWTyp==WT_ELEVON_B) then
              M_DB[MV_TAIL_TYPE] = TT_R1
            end
        end

        --- Did the tail changed?
        local tt = M_DB[MV_TAIL_TYPE]
        if (currTTyp ~= tt) then
            if (not tailTypeCompatible(currTTyp,tt)) then  
              ST_PlaneTailInit(tt)
            end
            currTTyp = tt
        end

        Phase = PH_WAIT_CMD
    elseif Phase == PH_EXIT_REQ then
       Phase=PH_EXIT_DONE
    end
end

-----

local function DSM_Display()
  -- For Headers
  ui.clearTouchRegistry()

  --Draw RX Menu
  if Phase == PH_RX_VER then
    return
  end

  if Menu.MenuId == 0 then return end; -- No Title yet

  -- Header Text 
  ui.drawFPHeader(0, Menu.Text)

  local y = ui.getFPLinesY()

  for i = 0, 6 do
    local line = MenuLines[i]

    if line and line.Text ~= nil then
      local heading = line.Text

      if (line.TextId >= 0x8000) then     -- Flight mode
        heading = GetFlightModeValue(line)
        ui.drawFPFlightMode(y, heading) -- display text
      elseif (line.TextId >= 0x5000) then     -- Render Image
        -- Render Image# TextID
        local imageName = string.format("IMG%X.jpg",line.TextId)
        ui.drawBitmap(1,y, imageName)
      elseif (line.Type == LT_MENU) then -- Menu or Sub-Headeer
        if (isSelectable(line)) then
          -- Menu to another page
          ui.drawFPMenuLine(y, heading, i, ctx_SelLine) -- display text
        else
          -- Menu lines with no navigation.. Just Sub-Header 
          ui.drawFPSubHeader(y, heading)
        end
      else
        -- Line with Value
        local text = nil
        if line.Val ~= nil then -- Value to display??
          text = line.Val

          if isListLine(line) then
            local textId = line.Val + line.TextStart
            text = Get_Text_Value(textId)
            
            -- image??
            local offset = 0
            --if (line.Type==LT_LIST_ORI) then offset = offset + 0x100 end --FH6250 hack
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

------------------------------------------------------------------------------------------------------------
local function hashName(mName)
  local c=10000;

  local prefix = string.gsub(mName,"%.","_") -- Change any "." to "_"
  prefix = string.gsub(prefix,"% ","_") -- Change any space to "_"
  prefix = string.sub(prefix,1,5) -- Take the first 5 characters

  -- Simple Hash of the Model Name adding each character 
  for i = 1, #mName do
      local ch = string.byte(mName,i,i)
      c=c+ch
  end

  return (prefix .. c) -- Return Prefix + Hash
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

  -- Find the multimodule 
  module = model.getModule(0) -- Internal
  if (module and module.Type==6) then
      print("Module(0) is multi-module")
  else
    module = model.getModule(1) -- External 
    if (module and module.Type==6) then
      print("Module(1) is multi-module")
    else
      print("No-MultiModule")
      module = nil
    end
  end

  -- Find the DSM "Disable channel mapping" option 
  if (module) then
    local chOrder = module.channelsOrder
    local s = getModuleChannelOrder(chOrder)
    
    
    if (s=="AETR") then
        print("Disable Ch Map  = ",true)
        TRANSLATE_AETR_TO_TAER = true
    end
  end

  local modelInfo = model.getInfo()
  MODEL.modelName = modelInfo.name

  --local path = modelInfo.path or modelInfo.name
  --MODEL.modelPath = string.gsub(path, ".bin", ".txt") -- change ".bin" for ".txt"


  MODEL.modelPath = hashName(MODEL.modelName)..".txt"
  
  print("Name ="..MODEL.modelName)
  print("Path ="..MODEL.modelPath)

  -- Read Info for Ch1 to Ch12
  local i= 0
  for i = 0, TX_CHANNELS-1 do 
      local ch = model.getOutput(i)
      if (ch~=nil) then
          local cht = { name=ch.name, min=ch.min/10, max=ch.max/10, revert=ch.revert, 
                       offset =ch.offset, ppmCenter=ch.ppmCenter, symetrical=ch.symetrical }  

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


-- Init
local function DSM_Init()
  LOG_open()
  ReadTxModelData()
  ST_LoadFileData()
  ST_Init()
  gc()
end

-- Main

local function create()
  print("PlaneSetup.create() called")
  DSM_Init()

    -- REMOVE when bug is fixed 
  local w,h = ui.getWindowSize()
  form.clear()
  form.addTextButton(nil, {x=w-2,y=h-2,w=2,h=2}, "XXX", function()  end)

  --form.setWindowTitle("Setup")
  return {}
end

local function close()
  print("PlanseSetup.close()")
  LOG_close()
end

local function wakeup(widget)
  --print("PlanseSetup.wakeup()")

  if (Phase == PH_INIT) then 

  elseif Phase == PH_EXIT_DONE then
      close()
      config.exit()
  else
      DSM_Send_Receive()
      if (refreshDisplay) then
        --lcd.invalidate()
        refreshDisplay=false
      end
  end
end

local function paint(widget)
  --print("PlaneSetup.paint() called")
  lcd.clear(ui.ms.screenBGColor)
  form.draw()
  DSM_Display()
end


local function event(widget, evt, touchState)
  --print("Event received:", evt)
  if (evt == EVT_TOUCH_FIRST) then
    local line = ui.touchToButtonValue(touchState.x,touchState.y)
    if (line and not isEditing()) then
      ctx_SelLine = line
      refreshDisplay=true
    end
  elseif (evt == EVT_TOUCH_TAP or evt == EVT_TOUCH_BREAK) then
    local line = ui.touchToButtonValue(touchState.x,touchState.y)
    if (line) then
      if (isEditing()) then
          local keyValue, rotarySpeed = ui.editValueToKeyEvent(line)
          if (keyValue) then
            DSM_HandleEvent(keyValue, rotarySpeed)
            refreshDisplay=true
          end
      else
          ctx_SelLine = line
          DSM_HandleEvent(EVT_VIRTUAL_ENTER, 1)
          refreshDisplay=true
          return false
      end -- if ctx_Editline
    end -- if line
  else
      DSM_HandleEvent(evt)
      refreshDisplay=true
  end -- touchState
  return 0
end


return { create=create, close=close, wakeup=wakeup, event=event, paint=paint}

