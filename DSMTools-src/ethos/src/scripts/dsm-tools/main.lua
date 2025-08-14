local config = {
  version = "v2.1.0",
  simulation = (system.getVersion().simulation == true),
  imagePath  = "img/",
  dataPath   = "data/",
  logPath    = "logs/",
  appsPath   = "apps/",
  libPath    = "lib/",
  msgPath    = "i18n/"
}

local translations = {en="DSM Tools"}

local ui  = assert(loadfile(config.libPath.."lib-ui.lua")) (config)

local function gc()
  collectgarbage("collect")
  return system.getMemoryUsage().luaRamAvailable/1024
end

local function loadScript(context,fileName)
  local initialMem =  gc()
  print("Loading ",fileName,"  FreeMem =",initialMem)

  local page = assert(loadfile(config.appsPath..fileName)) (config, ui)

  context.scriptFile = fileName
  context.create = page.create
  context.close  = page.close
  context.paint = page.paint
  context.event = page.event
  context.wakeup = page.wakeup
  local finalMem = gc()
  print("Loading Complete. FreeMem =",finalMem,"  Diff =",initialMem-finalMem)
end

local function unloadScript(context)
  local initialMem =  gc()
  print("unloadScript:",context.scriptFile, "  FreeMem =",initialMem)
  context.create = nil
  context.close  = nil
  context.paint  = nil
  context.event  = nil
  context.wakeup = nil
  local finalMem = gc()
  print("UnLoading Complete. FreeMem =",finalMem,"  Diff =",initialMem-finalMem)
end

local Setup = {}

function Setup.load()
    loadScript(Setup,"app-plane-setup.lua")
end

function Setup.unload()
    unloadScript(Setup)
end

local ForwardProg = {}

function ForwardProg.load()
    loadScript(ForwardProg,"app-fwd-prog.lua")
end

function ForwardProg.unload()
  unloadScript(ForwardProg)
end

local Telemetry = {}

function Telemetry.load()
    loadScript(Telemetry,"app-telemetry.lua")
end

function Telemetry.unload()
  unloadScript(Telemetry)
end

local Capture = {}

function Capture.load()
    loadScript(Capture,"app-capture.lua")
end

function Capture.unload()
  unloadScript(Telemetry)
end


local MainScreen = {
    ItemSelected = 1
}

MainScreen.menu = {
    --   Title,            Processor
      {title="Main Menu ",        proc=MainScreen}, 
      {title="Plane Setup",       proc=Setup,        icon="mask_flight_modes.png", index=1},
      {title="Forward Prog",      proc=ForwardProg,  icon="mask_rf_setup.png",     index=2},
      {title="Telemetry",         proc=Telemetry,    icon="mask_telemetry.png",    index=3},
      {title="Capture Data",      proc=Capture,      icon=nil,                     index=4},
}

function MainScreen.create()
    ui.init()  
    lcd.setWindowTitle("DSM Tools")
    local maxW, maxH = ui.getWindowSize()

    local this = MainScreen
    form.clear()
    local headerHeight = form.height() + 10
  
    for iParam=2, #this.menu do      
       local buttonText = this.menu[iParam].title
       local buttonMask = this.menu[iParam].icon
       local buttonIndex = this.menu[iParam].index

       local coords = ui.getMenuButtonDim(buttonIndex, 0, headerHeight)
              
       local button  = form.addButton(nil, coords, 
       {
        text = buttonText,
        icon = (buttonMask and lcd.loadMask(config.imagePath..buttonMask)) or nil,
        options =  nil, -- FONT_L,
        press = function()
            
            this.ItemSelected = iParam -- Activate current page
            local Proc   = this.menu[iParam].proc

            if (Proc.load) then
                Proc.load()
            end
  
            if (Proc.create) then
                form.clear()
                Proc.widget = Proc.create() -- Init of Processor
            end 
        end
      })
    end -- for

    --------------------- Buttom Text 
    
    
    local text = "Version "..config.version
    local w,h = ui.getTextPaddedSize(text)
    xPos = ui.ms.textWidthPad
    yPos = maxH - h  
    form.addStaticText(nil,  {x = xPos , y = yPos , w = w, h = h}, text)

    text = "Frankie Arzu/Pascal Langer"
    w,h = ui.getTextPaddedSize(text)
    xPos =  (maxW - w) 
    form.addStaticText(nil,  {x = xPos , y = yPos , w = w, h = h}, text)
  end
  
  function MainScreen.paint(widget)
  end
  
  function  MainScreen.event(key)
    local this    =  MainScreen
  
    print("MainScreen.event() called")
  
    --lcd.invalidate()
    return false
  end
  
---------------------------------------------------------------------------------------------

local function name()
    local locale = system.getLocale()
    return translations[locale] or translations["en"]
  end
  
  local function create()
    print("create() called")
    MainScreen.create()
    return {}
  end
  
  local function close(widget)
    print("close()")
    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc

    if (Proc.close) then
        Proc.close(Proc.widget)
        Proc =  nil
        MainScreen.ItemSelected = 1
        gc()
        system.exit()
    end
  end
  
  local function wakeup(widget)
    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc
  
    if (Proc.wakeup) then
      Proc.wakeup(Proc.widget)
    end
  end
  
  local function paint(widget)
    --print("paint() called")
    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc
  
    if (Proc.paint) then
      Proc.paint(Proc.widget)
    end
  end
  
  local function event(widget, category, value, x, y)
    --print("main.event(): Event received:", category, value, x, y)
    local m  =  MainScreen

    if category == EVT_KEY or category == EVT_TOUCH then
      local m  =  MainScreen
      local Proc   = m.menu[m.ItemSelected].proc
  
      if (Proc.event) then
        return Proc.event(Proc.widget, category, value, x, y)
      end
    elseif (category == EVT_CLOSE and m.ItemSelected > 1) or 
           value == 35 then
      print("EVT_CLOSE")
      return true
    end 
    return false
  end

  function config.exit()
    print("config.exit()")

    system.killEvents(KEY_ENTER_BREAK)

    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc

    if (Proc.unload) then
        Proc.unload()
    end
  
    MainScreen.ItemSelected = 1
    MainScreen.create()
  end
  
  
  local icon = lcd.loadMask("icon.png")
  
  local function init()
    print("init() called")
    system.registerSystemTool({name=name, icon=icon, create=create, close=close, wakeup=wakeup, event=event, paint=paint})
  end
  
  return {init=init}
