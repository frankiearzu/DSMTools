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

local form = { title = "", objects={}, lines = {}}

function form.setWindowTitle(title)
    form.title = title
  end
  
  function form.clear()
    form.objects = {}
    form.lines = {}
    
    local tw,th = lcd.sizeText("O")
  
    form.focus = 0
    form.lineH = th * 1.2  
  end
  
  function form.height()
    local y = form.lineH
    y = y + form.lineH * #form.lines
    return y
  end
  
  function form.addLine(text,data)
    
    local self = { type="L", coords={x=0, y=form.height(),w=LCD_W,h=form.lineH}, text=text }

    function self.draw(focus)
      local c = self.coords
      lcd.drawText(c.x, c.y, self.text)
    end

    function self.covers(x,y)
      return false
    end

    local nextPos = #form.lines+1
    form.lines[nextPos] = self

    return self
  end
  
  function form.addButton(line, coords, data)
    local textW, textH =  lcd.sizeText(data.text)
    if (coords==nil and line ~= nil) then  
      print("form.addButton: using line reference")
      coords = { x = line.coords.x + line.coords.w - (textW * 1.5), y = line.coords.y, textW, line.coords.h,
                 w =textW, h = textH}
    end
  
    local self = { type="B", coords=coords, data=data }
    self.textW, self.textH = textW,textH

    function self.print()
        local c = self.coords
        print("form.addButton:")
        print(string.format("Coords = (x=%d,y=%d,w=%d,h=%d)",c.x, c.y, c.w, c.h))
        print(string.format("text = \"%s\"",self.data.text))
    end

    function self.covers(x,y)
      local c = self.coords
      return (x > c.x) and (x < (c.x + c.w)) and
             (y > c.y) and (y < (c.y + c.h))
    end

    function self.draw(focus)
        local c = self.coords
  
        local color =  WHITE
        if (focus) then color = ORANGE end
        lcd.drawFilledRectangle(c.x, c.y, c.w,c.h, color)
        lcd.drawRectangle(c.x, c.y, c.w,c.h, LIGHTGREY)
  
  
        local color =  BLACK
        if (focus) then color = WHITE end
        local text = self.data.text  
        lcd.drawText(c.x + c.w / 2, c.y + (c.h - self.textH) / 2, text, color + CENTER)
    end
  
    local nextPos = #form.objects+1
    form.objects[nextPos] = self
    
    if (form.focus == 0) then
      form.focus = nextPos
    end
  
    --attr.text = this.menu[iParam][1],
    --attr.icon = nil, -- you can load a mask and put an image into the button
    --attr.options = nil, -- FONT_S,
    --attr.press 

    self.print()
    return self
  end
  
  function form.addTextButton(line, coords, text, pressF)
      local data = {}
      data.text = text
      data.press = pressF
      return form.addButton(line, coords, data)
  end
  
  
  function form.draw()
    lcd.drawFilledRectangle(0,0, LCD_W,form.lineH * 1.2, DARKBLUE)
    lcd.drawText(10,0, form.title, WHITE)
  
    for i=1, #form.lines do
      local obj = form.lines[i]
      obj.draw(false)
    end
  
  
    for i=1, #form.objects do
      local obj = form.objects[i]
        local focus = (i==form.focus)
        obj.draw(focus)
    end -- for
  end
  
  function form.event(evt,touch)
    if (evt == EVT_TOUCH_FIRST) then
      for i=1, #form.objects do
        local obj = form.objects[i]
        --print("Touch: obj[",i,"]",obj or "nil")
        if (obj and obj.covers(touch.x,touch.y)) then
          form.focus = i
          form.draw()
          return 0
        end
      end -- for
    elseif (evt == EVT_TOUCH_TAP or evt == EVT_TOUCH_BREAK) then
      for i=1, #form.objects do
        local obj = form.objects[i]
        --print("Touch: obj[",i,"]",obj or "nil")
        if (obj and obj.covers(touch.x,touch.y)) then
          form.focus = i
          --form.draw()
          obj.data.press()
          return 0
        end
      end -- for  
    elseif (evt == EVT_VIRTUAL_NEXT) then
      if (form.focus < #form.objects) then
        form.focus = form.focus + 1
      end
    elseif (evt == EVT_VIRTUAL_PREV) then
      if (form.focus >  1) then
        form.focus = form.focus - 1
      end
    elseif (evt == EVT_VIRTUAL_ENTER) then
      local obj = form.objects[form.focus]
      obj.data.press()
    elseif (evt == EVT_VIRTUAL_EXIT) then
      return 2
    end
  
    return 0
  end
  

return form