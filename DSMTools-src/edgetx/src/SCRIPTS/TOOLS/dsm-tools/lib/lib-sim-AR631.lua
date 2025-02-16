
local arg = {...}
local callback = arg[1]  -- Callbacks to main Forward Prog

local sim = {}

-- Line Types
local LT_MENU                                            = 0x1C 
local LT_LIST_NC , LT_LIST_NC2                    = 0x6C, 0x6D 
local LT_LIST , LT_LIST_ORI , LT_LIST_TOG  = 0x0C, 0xCC, 0x4C
local LT_VALUE_NC                                        = 0x60
local LT_VALUE_PERCENT , LT_VALUE_DEGREES         = 0xC0, 0xE0 
local LT_VALUE_PREC2                                     = 0x69

local lastGoodMenu = 0
local RX_Initialized = true

function sim.setRXInitialized(v)
    RX_Initialized = v
end

function sim.AR631_getMenu(menuId)
  if (menuId==0) then menuId = 0x1000 end

  local ctx_CurLine = -1
  local ctx_SelLine = -1     -- highlight Back
  local Menu = {}
  local MenuLines = {}

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
    Menu.Text = callback.Get_Text(Menu.TextId)
  end

  for i = 0, 6 do     -- Set Text
    local line = MenuLines[i]
    if (line.TextId > 0) then
      line.MenuId = Menu.MenuId
      line.Text = callback.Get_Text(line.TextId)
      print(string.format("MenuLine[%d] = \"%s\"",i,line.Text))

      if callback.isListLine(line) then                         
        line.TextStart = line.Min
        line.Def = line.Def - line.Min -- normalize default value 
        line.Max = line.Max - line.Min -- normalize max index
        line.Min = 0 -- min index
        line.Val = line.Val - line.TextStart
      end

      callback.updateValText(line)
    end -- if line.TextId
  end -- for

  local data = {}

    data.ctx_CurLine = ctx_CurLine
    data.ctx_SelLine = ctx_SelLine
    data.Menu        = Menu
    data.MenuLines   = MenuLines

    return data
end


return sim