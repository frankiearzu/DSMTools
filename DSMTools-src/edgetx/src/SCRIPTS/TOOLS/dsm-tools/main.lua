
local PATH = "/SCRIPTS/TOOLS/dsm-tools"
chdir(PATH)

local config = {
  version = "v2.3",
  simulation = string.sub(select(2,getVersion()), -4) == "simu",
  imagePath  = PATH.."/img/",
  dataPath   = "/MODELS/DSMDATA/", --"data/",
  logPath    = "logs/",  -- or could be "/LOGS/" to use the global LOGS folder
  appsPath   = "apps/",
  libPath    = "lib/",
  msgPath    = "i18n/"
}

local form = assert(loadfile(config.libPath.."lib-form.lua")) ()
local ui  = assert(loadfile(config.libPath.."lib-ui.lua")) (config)


local function gc()
  return collectgarbage("collect") or 0
end

local function loadScript(context,fileName)
  local initialMem =  gc()
  print("Loading ",fileName,"  FreeMem =",initialMem)

  local page = assert(loadfile(config.appsPath..fileName)) (config, ui, form)

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
    form.setWindowTitle("DSM Tools")
    local maxW, maxH = ui.getWindowSize()

    local this = MainScreen
    form.clear()
    local headerHeight = form.height() + 10
  
    for iParam=2, #this.menu do      
       local buttonText = this.menu[iParam].title
       local buttonMask = nil --this.menu[iParam].icon
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
    
    return {}
  end
  
  function MainScreen.paint(widget)
    lcd.clear(ui.ms.screenBGColor)
    form.draw()

    local attr = DARKGREY
    local text = "Version "..config.version
    local w,h = ui.getTextPaddedSize(text)
    local xPos = ui.ms.textWidthPad
    local yPos = LCD_H - h  
    lcd.drawText(xPos, yPos, text, attr)

    text = "Frankie Arzu/Pascal Langer"
    w,h = ui.getTextPaddedSize(text)
    xPos =  (LCD_W - w) 
    lcd.drawText(xPos, yPos, text, attr)
  end
  
  function  MainScreen.event(widget, evt, touchState)
    local this    =  MainScreen
  
    --print("MainScreen.event() called")
  
    return form.event(evt, touchState)
  end
  
---------------------------------------------------------------------------------------------
  
  local function create()
    print("create() called")
    return MainScreen.create()
  end
  
  local exitScript = false
  local function close(widget)
    print("close()")
    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc

    if (Proc.close) then
        Proc.close(Proc.widget)
        Proc =  nil
        MainScreen.ItemSelected = 1
        gc()
        exitScript = true
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
  
  local function event(widget, evt, touchState)
    --print("main.event(): Event received:", category, value, x, y)
    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc

    if (Proc.event) then
      return Proc.event(Proc.widget, evt, touchState)
    end
    return 0
  end

  function config.exit()
    print("config.exit()")

    --system.killEvents(KEY_ENTER_BREAK)

    local m  =  MainScreen
    local Proc   = m.menu[m.ItemSelected].proc

    if (Proc.close) then
      Proc.close()
    end

    if (Proc.unload) then
        Proc.unload()
    end
  
    MainScreen.ItemSelected = 1
    MainScreen.create()
  end
  
  
  --local icon = lcd.loadMask("icon.png")
  
  local widget = nil

  local function init()
    print("init() called")
    --system.registerSystemTool({name=name, icon=icon, create=create, close=close, wakeup=wakeup, event=event, paint=paint})
    widget = create()
  end

  local function run(evt, touchState)
    if evt == nil then
      error("Cannot be run as a model script!")
      return 2
    end

    event(widget, evt, touchState)
    
    if (exitScript) then
        return 2 -- exit 
    end

    wakeup(widget)
    paint(widget)

    return 0 -- continue running
  end

  
  return {init=init, run=run}
