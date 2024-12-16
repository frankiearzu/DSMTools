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


local LCD_W, LCD_H                

local lcdTouchButtons = {}

local ui = {}

local supportedRadios = {
    -- TANDEM X20, TANDEM XE (800x480)
    ["784x406"] = {
        ms = {
            textWidthPad        = 5,
            textHeightPad       = 5,
            
            touchYOffeset       = 68
        },
        menu = {
            buttonWidth     = 240,
            buttonHeight    = 160,
            buttonWidthPad  = 50,
            buttonHeightPad = 20,
            buttonPerRow    = 2,
        },
        fp = {
            textFont            = FONT_STD,
            textFontBold        = FONT_BOLD,
            headerFont          = FONT_XL,
        },
    },
    -- TANDEM X18, TWIN X Lite (480x320)
    ["472x288"] = {
        ms = {
            textWidthPad        = 5,
            textHeightPad       = 5,

            touchYOffeset       = 30   
        },
        menu = {
            buttonWidth     = 140,
            buttonHeight    = 80,
            buttonWidthPad  = 30,
            buttonHeightPad = 10,
            buttonPerRow    = 2,
        },
        fp = {
            textFont            = FONT_STD,
            textFontBold        = FONT_BOLD,
            headerFont          = FONT_XL,
        },
    },
    -- Horus X10, Horus X12 (480x272)
    ["472x240"] = {
        ms = {
            textWidthPad        = 5,
            textHeightPad       = 4,

            touchYOffeset       = 0, -- no touch screen
        },
        menu = {
            buttonWidth     = 140,
            buttonHeight    = 80,
            buttonWidthPad  = 30,
            buttonHeightPad = 10,
            buttonPerRow    = 2,
        },
        fp = {
            textFont            = FONT_STD,
            textFontBold        = FONT_BOLD,
            headerFont          = FONT_BOLD,
        },
    },
    -- Twin X14 (632x314)
    ["632x314"] = {
        ms = {
            textWidthPad        = 5,
            textHeightPad       = 5,

            touchYOffeset       = 68   
        },
        menu = {
            buttonWidth     = 140,
            buttonHeight    = 80,
            buttonWidthPad  = 30,
            buttonHeightPad = 10,
            buttonPerRow    = 2,
        },
        fp = {
            textFont            = FONT_STD,
            textFontBold        = FONT_BOLD,
            headerFont          = FONT_XL,
        },
    }
}

function ui.init()
    LCD_W, LCD_H = lcd.getWindowSize()
    local resolution = LCD_W .. "x" .. LCD_H
    local radio = supportedRadios[resolution]
    if not radio then
        -- default to the lower resolution if not found 
        radio = supportedRadios["472x240"]
    end

    ui.ms = radio.ms
    ui.menu = radio.menu
    ui.fp   = radio.fp

    -- Compute Dynamic FP settings
    ui.fp.textColor       = lcd.themeColor(THEME_DEFAULT_COLOR)
    ui.fp.textBGColor     = lcd.themeColor(THEME_DEFAULT_BGCOLOR)
    ui.fp.focusColor      = lcd.themeColor(THEME_FOCUS_COLOR)
    ui.fp.focusBGColor    = lcd.themeColor(THEME_FOCUS_BGCOLOR)

    ui.fp.editBoxColor    = lcd.themeColor(THEME_WARNING_COLOR)

    ui.fp.headerColor     = ui.fp.textColor


    -- Compute Header Size
    lcd.font(ui.fp.headerFont)
    local hTw, hTh = lcd.getTextSize("BACK")

    -- Compute Line Size
    lcd.font(ui.fp.textFont)
    local tw, th = lcd.getTextSize("BACK")

    -- Dynamicall conpute the size of the line in FP

    ui.fp.buttonWidth  = hTw + ui.ms.textWidthPad
    ui.fp.buttonHeight   = hTh + ui.ms.textHeightPad
  
    ui.fp.lineHeight   = th + ui.ms.textHeightPad
    ui.fp.headerHeight = ui.fp.buttonHeight
  
    ui.fp.rightButtonXpos  = LCD_W - ui.fp.buttonWidth - 1
    ui.fp.lowerButtonYpos  = LCD_H - ui.fp.buttonHeight - (ui.ms.textHeightPad // 2)
end

function ui.clearTouchRegistry()
    lcdTouchButtons = {}
end

function ui.getWindowSize()
    return LCD_W, LCD_H
end

function ui.getTextPaddedSize(text)
    local w, h = lcd.getTextSize(text)
    return w + ui.ms.textWidthPad, h + ui.ms.textHeightPad
end

function ui.getTouchCoord(x,y)
    return x, y - ui.ms.touchYOffeset
end

function ui.getMenuButtonDim(index, xOffset, yOffset)
    local rowUsedWidth = (ui.menu.buttonWidth+ui.menu.buttonWidthPad)* ui.menu.buttonPerRow
    local xOffset = xOffset + (LCD_W - rowUsedWidth)/2


    local row = (index-1) // ui.menu.buttonPerRow
    local col = (index-1) % ui.menu.buttonPerRow

    local x = xOffset + col * (ui.menu.buttonWidth+ui.menu.buttonWidthPad) 
    local y = yOffset + row * (ui.menu.buttonHeight+ui.menu.buttonHeightPad)

    return {x=x, y=y, w=ui.menu.buttonWidth, h = ui.menu.buttonHeight}
end

function ui.flipColor(active, activeColor, inactiveColor)
    if (active) then
      lcd.color(activeColor)
    else
      lcd.color(inactiveColor)
    end
end

function ui.getFPLinesY()
    return ui.fp.headerHeight + ui.ms.textHeightPad*4
end

function ui.getFPLineHeight()
    return ui.fp.lineHeight
end

function ui.getFPBottomLineY()
    return ui.fp.lowerButtonYpos
end

function ui.getFPLinesHeightPad()
    return ui.ms.textHeightPad
end

function ui.drawFPHeader(y, text)
    lcd.font(ui.fp.headerFont)
    lcd.color(ui.fp.headerColor)
    lcd.drawText(LCD_W // 2, y, text, TEXT_CENTERED)

    y = y + ui.fp.headerHeight + 2
    lcd.color(ui.fp.textColor)
    lcd.drawLine(0, y, LCD_W, y)
end

function ui.drawFPSubHeader(y, text)
    lcd.font(ui.fp.textFont)
    lcd.color(ui.fp.textColor)
    lcd.drawText(LCD_W // 2, y, text, TEXT_CENTERED)
end

function ui.drawFPFlightMode(y, text)
    lcd.font(ui.fp.textFontBold)
    lcd.color(ui.fp.textColor)
    lcd.drawText(LCD_W // 2, y, text, TEXT_CENTERED)
end

function ui.drawFPMenuLine(y, text, lineNo, focusLineNo)
    lcd.font(ui.fp.textFont)

    local w,h = lcd.getTextSize(text)
    local yPad = (ui.fp.lineHeight-h) // 2

    local isFocus = lineNo==focusLineNo
    
    local x =  1
    local w =  LCD_W

    ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textBGColor)
    lcd.drawFilledRectangle(x, y, w, ui.fp.lineHeight)
  
    ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textColor)
    lcd.drawText(ui.ms.textWidthPad, y+yPad, text) 
  
    lcdTouchButtons[#lcdTouchButtons+1] = {x=x, y=y, w=w, h=ui.fp.lineHeight,v=lineNo}
end


function ui.drawFPValueLine(y, heading, value, lineNo, focusLineNo, editingLine)
    lcd.font(ui.fp.textFont)
    lcd.color(ui.fp.textColor)

    local w,h = lcd.getTextSize(heading)
    local yPad = (ui.fp.lineHeight-h) // 2

    local isFocus = lineNo==focusLineNo
    local isEditting =  lineNo == editingLine
    -- Heaing 
    lcd.drawText(ui.ms.textWidthPad, y+yPad, heading)

    local x = LCD_W
    -- Line with Value
    local w =  (LCD_W // 3)
    ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textBGColor)
    lcd.drawFilledRectangle(x-w, y, w, ui.fp.lineHeight)  
    
    ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textColor)
    lcd.drawText(x - ui.ms.textWidthPad, y+yPad, value, TEXT_RIGHT)
  
    if (isEditting) then
      lcd.color(ui.fp.editBoxColor)
      lcd.drawRectangle(x-w, y, w, ui.fp.lineHeight, 2)
    end 
  
    lcdTouchButtons[#lcdTouchButtons+1] = {x=x-w, y=y, w=w, h=ui.fp.lineHeight, v=lineNo}
end

function ui.drawBitmap(x, y, imgDesc)
    local f = string.gmatch(imgDesc, '([^%|]+)')   -- Iterator over values split by '|'
    local imgName, imgMsg = f(), f()
  
    f = string.gmatch(imgMsg or "", '([^%:]+)')   -- Iterator over values split by ':'
    local p1, p2 = f(), f()
  
    local textX = x + (LCD_W // 2) + ui.ms.textWidthPad
    lcd.font(ui.fp.textFont)
    lcd.color(ui.fp.textColor)
    lcd.drawText(textX, y, p1 or "")              -- Alternate Image MSG
    lcd.drawText(textX, y + ui.fp.lineHeight, p2 or "") -- Alternate Image MSG
  
    local bitMap = lcd.loadBitmap(config.imagePath..imgName)
    if (bitMap) then
      -- Bitmat resized to 4 line hight, and 1/2 screen width 
      lcd.drawBitmap(x, y, bitMap, LCD_W // 2, ui.fp.lineHeight*4)
    end
  end
  
function ui.drawButton(x, y, text, lineNo, focusLineNo)
    lcd.font(ui.fp.textFontBold)

    local w,h = lcd.getTextSize(text)
    local yPad = (ui.fp.buttonHeight-h)/2

    local isFocus = lineNo==focusLineNo
    ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textBGColor)
    lcd.drawFilledRectangle(x, y, ui.fp.buttonWidth, ui.fp.buttonHeight)  
    
    ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textColor)
    lcd.drawText(x+ui.fp.buttonWidth/2, y+yPad, text, TEXT_CENTERED)

    --lcd.drawRectangle(x, y, LCD_W_BUTTONS-1, LCD_LINE_H) 
  
    lcdTouchButtons[#lcdTouchButtons+1] = {x=x, y=y, w=ui.fp.buttonWidth, h=ui.fp.buttonHeight, v=lineNo}
end

function ui.touchToButtonValue(x,y)
    y = y - ui.ms.touchYOffeset
  
    --print("touchToButtonValue ",x,y)
    for i=1, #lcdTouchButtons do
      local coords = lcdTouchButtons[i]
      --print("Button"..i,coords.x,coords.y)
  
      if (x >= coords.x and x <= coords.x + coords.w) and
         (y >= coords.y and y <= coords.y + coords.h) then
          print("Found button-"..i,coords.v)
          return coords.v
      end
    end
    return nil 
end


function ui.drawEditButtons()
    local x = 20
    ui.drawButton(x, ui.fp.lowerButtonYpos, "<<-",  1001, 0)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "<-",   1002, 0)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "->",   1003, 0)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "->>",  1004, 0)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "Def", 1005, 0)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "Esc", 1006, 0)

    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "OK",  1007, 0)
end

function ui.editValueToKeyEvent(line)
    local e = nil
    local rotarySpeed = 1

    if (line == 1001) then e=KEY_ROTARY_LEFT; rotarySpeed = 10
    elseif (line == 1002) then e=KEY_ROTARY_LEFT
    elseif (line == 1003) then e=KEY_ROTARY_RIGHT
    elseif (line == 1004) then e=KEY_ROTARY_RIGHT; rotarySpeed = 10
    elseif (line == 1005) then e=KEY_ENTER_LONG
    elseif (line == 1006) then e=KEY_RTN_BREAK
    elseif (line == 1007) then e=KEY_ENTER_FIRST
    end
    
    return e, rotarySpeed
end



---------

return ui