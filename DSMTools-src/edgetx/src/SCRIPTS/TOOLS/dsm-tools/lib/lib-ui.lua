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

local lcdTouchButtons = {}

local ui = {}

local refreshScreen = true

local supportedRadios = {
    -- Horus X10, Horus X12 (480x272)
    ["472x240"] = {
        ms = {
            textWidthPad        = 5,
            textHeightPad       = 4,

            touchYOffeset       = 0, -- no offset
            screenBGColor       = LIGHTWHITE
        },
        menu = {
            buttonWidth     = 140,
            buttonHeight    = 80,
            buttonWidthPad  = 30,
            buttonHeightPad = 10,
            buttonPerRow    = 2,
        },
        fp = {
            textFont            = 0,
            textFontBold        = BOLD,
            headerFont          = BOLD,
        },
    },
}

function ui.init()
    local resolution = LCD_W .. "x" .. LCD_H

    print("UI Resolution:", resolution)
    local radio = supportedRadios[resolution]
    if not radio then
        -- default to the lower resolution if not found 
        radio = supportedRadios["472x240"]
    end

    ui.ms = radio.ms
    ui.menu = radio.menu
    ui.fp   = radio.fp

    -- Compute Dynamic FP settings
    ui.fp.textColor       = BLACK
    ui.fp.textBGColor     = ui.ms.screenBGColor
    ui.fp.focusColor      = WHITE
    ui.fp.focusBGColor    = ORANGE

    ui.fp.editBoxColor    = RED
    ui.fp.boxColor        = LIGHTGREY

    ui.fp.headerColor     = WHITE
    ui.fp.headerBGColor   = DARKBLUE


    -- Compute Header Size
    local hTw, hTh = lcd.sizeText("BACK", ui.fp.headerFont)

    -- Compute Line Size
    local tw, th = lcd.sizeText("BACK", ui.fp.textFont)

    -- Dynamicall conpute the size of the line in FP

    ui.fp.buttonWidth  = hTw + ui.ms.textWidthPad
    ui.fp.buttonHeight   = hTh + ui.ms.textHeightPad * 1.5
  
    ui.fp.lineHeight   = th + ui.ms.textHeightPad * 2
    ui.fp.headerHeight = ui.fp.buttonHeight
  
    ui.fp.rightButtonXpos  = LCD_W - ui.fp.buttonWidth - 1
    ui.fp.lowerButtonYpos  = LCD_H - ui.fp.buttonHeight -- - (ui.ms.textHeightPad / 2)
end

function ui.clearTouchRegistry()
    lcdTouchButtons = {}
end

function ui.getWindowSize()
    return LCD_W, LCD_H
end

function ui.getTextPaddedSize(text)
    local w, h = lcd.sizeText(text)
    return w + ui.ms.textWidthPad, h + ui.ms.textHeightPad
end

function ui.getTouchCoord(x,y)
    return x, y - ui.ms.touchYOffeset
end

function ui.getMenuButtonDim(index, xOffset, yOffset)
    local rowUsedWidth = (ui.menu.buttonWidth+ui.menu.buttonWidthPad)* ui.menu.buttonPerRow
    local xOffset = xOffset + (LCD_W - rowUsedWidth)/2


    local row = math.floor((index-1) / ui.menu.buttonPerRow)
    local col = (index-1) % ui.menu.buttonPerRow

    local x = xOffset + col * (ui.menu.buttonWidth+ui.menu.buttonWidthPad) 
    local y = yOffset + row * (ui.menu.buttonHeight+ui.menu.buttonHeightPad)

    return {x=x, y=y, w=ui.menu.buttonWidth, h = ui.menu.buttonHeight}
end

function ui.flipColor(active, activeColor, inactiveColor)
    if (active) then
      return activeColor
    else
      return inactiveColor
    end
end

function ui.getFPLinesY()
    return ui.fp.headerHeight + ui.ms.textHeightPad*2
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
    lcd.drawFilledRectangle(0, y, LCD_W, ui.fp.lineHeight, ui.fp.headerBGColor)
    local attr = ui.fp.headerFont + ui.fp.headerColor
    lcd.drawText(LCD_W / 2, y, text, CENTER + attr)

    y = y + ui.fp.headerHeight + 2
    lcd.drawLine(0, y, LCD_W, y, ui.fp.textColor)
end

function ui.drawFPSubHeader(y, text)
    local attr = ui.fp.textFont + ui.fp.textColor
    lcd.drawText(LCD_W / 2, y, text, CENTER + attr)
end

function ui.drawFPFlightMode(y, text)
    local attr = ui.fp.textFontBold + ui.fp.textColor
    lcd.drawText(LCD_W / 2, y, text, CENTER + attr)
end

function ui.drawFPMenuLine(y, text, lineNo, focusLineNo)
    local attr = ui.fp.textFont

    local w,h = lcd.sizeText(text,attr)
    local yPad = (ui.fp.lineHeight-h) / 2

    local isFocus = lineNo==focusLineNo
    
    local x =  1
    local w =  LCD_W - 3
    attr = ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textBGColor)
    lcd.drawFilledRectangle(x, y, w, ui.fp.lineHeight, attr)

    lcd.drawRectangle(x, y, w, ui.fp.lineHeight, ui.fp.boxColor)
  
    attr = ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textColor)
    lcd.drawText(ui.ms.textWidthPad, y+yPad, text, attr) 
  
    lcdTouchButtons[#lcdTouchButtons+1] = {x=x, y=y, w=w, h=ui.fp.lineHeight,v=lineNo}
end


function ui.drawFPValueLine(y, heading, value, lineNo, focusLineNo, editingLine)
    local attr = ui.fp.textFont + ui.fp.textColor

    local w,h = lcd.sizeText(heading, attr)
    local yPad = (ui.fp.lineHeight-h) / 2

    local isFocus = lineNo==focusLineNo
    local isEditting =  lineNo == editingLine
    -- Heaing 
    lcd.drawText(ui.ms.textWidthPad, y+yPad, heading, attr)

    local x = LCD_W - 5
    -- Line with Value
    local w =  (LCD_W / 3)

    if (isEditting) then
        attr = ui.fp.editBoxColor
    else
        attr = ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textBGColor)
    end

    lcd.drawFilledRectangle(x-w, y, w, ui.fp.lineHeight, attr)  
    
    attr = ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textColor)
    lcd.drawText(x - ui.ms.textWidthPad, y+yPad, value, RIGHT + attr)
  
    
    attr = ui.fp.boxColor  
    
    lcd.drawRectangle(x-w, y, w, ui.fp.lineHeight, attr)

    lcdTouchButtons[#lcdTouchButtons+1] = {x=x-w, y=y, w=w, h=ui.fp.lineHeight, v=lineNo}
end

function ui.drawBitmap(x, y, imgDesc)
    local f = string.gmatch(imgDesc, '([^%|]+)')   -- Iterator over values split by '|'
    local imgName, imgMsg = f(), f()
  
    f = string.gmatch(imgMsg or "", '([^%:]+)')   -- Iterator over values split by ':'
    local p1, p2 = f(), f()
  
    local textX = x + (LCD_W / 2) + ui.ms.textWidthPad * 8
    local attr = ui.fp.textFont + ui.fp.textColor
    lcd.drawText(textX, y, p1 or "", attr)                    -- Alternate Image MSG
    lcd.drawText(textX, y + ui.fp.lineHeight, p2 or "", attr) -- Alternate Image MSG
  
    local bitMap = Bitmap.open(config.imagePath..imgName)
    if (bitMap) then
      -- Bitmat resized to 4 line hight, and 1/2 screen width 
      lcd.drawBitmap(bitMap, x,y)
    end
  end
  
function ui.drawButton(x, y, text, lineNo, focusLineNo)
    local attr = ui.fp.textFontBold

    local w,h = lcd.sizeText(text, attr)
    local yPad = (ui.fp.buttonHeight-h)/2

    local isFocus = lineNo==focusLineNo
    attr = ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textBGColor)
    lcd.drawFilledRectangle(x, y, ui.fp.buttonWidth, ui.fp.buttonHeight, attr)  
    
    attr = ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textColor)
    lcd.drawText(x+ui.fp.buttonWidth/2, y+yPad, text, CENTER + attr)

    lcd.drawRectangle(x, y, ui.fp.buttonWidth, ui.fp.buttonHeight, ui.fp.boxColor) 
  
    lcdTouchButtons[#lcdTouchButtons+1] = {x=x, y=y, w=ui.fp.buttonWidth, h=ui.fp.buttonHeight, v=lineNo}
end

function ui.drawMenuButton(x, y, text, lineNo, focusLineNo)
    local attr = ui.fp.textFontBold

    local w,h = lcd.sizeText(text, attr)
    local yPad = (ui.fp.buttonHeight-h) / 2

    local isFocus = lineNo==focusLineNo
    attr = ui.flipColor(isFocus,ui.fp.focusBGColor,ui.fp.textBGColor)
    lcd.drawFilledRectangle(x, y, ui.fp.buttonWidth, ui.fp.buttonHeight, attr)  
    
    attr = ui.flipColor(isFocus,ui.fp.focusColor,ui.fp.textColor)
    lcd.drawText(x+ui.fp.buttonWidth/2, y+yPad, text, CENTER + attr)

    lcd.drawRectangle(x, y, ui.fp.buttonWidth, ui.fp.buttonHeight, ui.fp.boxColor) 
  
    lcdTouchButtons[#lcdTouchButtons+1] = {x=x, y=y, w=ui.fp.buttonWidth, h=ui.fp.buttonHeight, v=lineNo}
end


function ui.touchToButtonValue(x,y)
    y = y - ui.ms.touchYOffeset
  
    print("touchToButtonValue ",x,y)
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
    ui.drawButton(x, ui.fp.lowerButtonYpos, "<<",  1001, 1001)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "<",   1002, 1002)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, ">",   1003, 1003)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, ">>",  1004, 1004)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "Def", 1005, 1005)
    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "Esc", 1006, 1006)

    x = x + ui.fp.buttonWidth + 10
    ui.drawButton(x, ui.fp.lowerButtonYpos, "OK",  1007, 1007)
end

function ui.editValueToKeyEvent(line)
    local e = nil
    local rotarySpeed = 1

    if (line == 1001) then e=EVT_VIRTUAL_PREV; rotarySpeed = 10
    elseif (line == 1002) then e=EVT_VIRTUAL_PREV
    elseif (line == 1003) then e=EVT_VIRTUAL_NEXT
    elseif (line == 1004) then e=EVT_VIRTUAL_NEXT; rotarySpeed = 10
    elseif (line == 1005) then e=EVT_VIRTUAL_ENTER_LONG
    elseif (line == 1006) then e=EVT_VIRTUAL_EXIT
    elseif (line == 1007) then e=EVT_VIRTUAL_ENTER
    end
    
    return e, rotarySpeed
end

return ui