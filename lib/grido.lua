-- grido
local json=include("oooooo/lib/json")
local graphic_pixels=include("oooooo/lib/glyphs")

local Grido={}

-- copied from ooooooo
local page_loops = 1
local page_tones = 2
local page_volume = 3
local page_pan = 4
local page_rate = 5
local page_frequency = 6
local page_macro_record = 7 
local page_macro_play = 8

function Grido:new(args)
  local m=setmetatable({},{__index=Grido})
  local args=args==nil and {} or args

  -- initiate the grid
  m.g=grid.connect()
  m.g.key=function(x,y,z)
    m:grid_key(x,y,z)
  end
  print("grid columns: "..m.g.cols)

  -- 16 or 8 width
  m.grid_width = 16 
  m.rates = {-400,-200,-150,-100,-75,-50,-25,-12.5,12.5,25,50,75,100,150,200,400}
  m.rates_index = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
  m.octave_index = {9,10,11,13,15,16}
  m.periods = {96,48,24,12,10,8,6,4,3.2,2.4,1.6,1.2,0.8,0.4,0.2,0.1}
  if m.g.cols == 8 then 
    m.grid_width = 8
    m.rates = {-200,-100,-50,-25,25,50,100,200}
    m.rates_index = {2,4,6,7,10,11,13,15}
    m.octave_index = {5,6,7,8}
    m.periods = {60,30,15,7,4,2,1,0.3}
  end
  print("grid width: "..m.grid_width)

  -- macros
  m.macro_db = {}
  m.macro_clock = {}
  m.macro_current = {}
  m.macro_play = false
  m.macro_record = false

  -- selection 
  m.selection = 1
  m.selection_scale = math.floor(2/3*m.grid_width)
  m.current_octave = {4,4,4,4,4,4}
  m.show_graphic = {nil,0}

  -- setup visual
  m.shown_text={false,false,false,false,false,false,false}
  m.visual={}
  for i=1,8 do
    m.visual[i]={}
    for j=1,m.grid_width do
      m.visual[i][j]=0
    end
  end

  -- debouncing and blinking
  m.blink_count=0
  m.blinky={}
  for i=1,m.grid_width do
    m.blinky[i]=1 -- 1 = fast, 16 = slow
  end

  -- grid uses pre-defined max loop length
  m.loopMax=0
  for i=1,6 do
    if params:get(i.."length") > m.loopMax then 
      m.loopMax = params:get(i.."length")
    end
  end

  m.pressed_buttons={}

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.05
  m.grid_refresh.event=function()
    if m.g.cols > 0 then 
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  return m
end

function Grido:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function Grido:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=true
  else
    self.pressed_buttons[row..","..col]=nil
  end

  if row <= 6 and on then 
    loopStart,loopEnder = self:get_touch_points(row)
    if self.selection == page_loops then 
      self:change_loop(row,loopStart,loopEnder)
      if self.macro_record then 
        self:macro_add("oooooo_grid:change_loop("..row..","..loopStart..","..loopEnder..",false)")
      end
    elseif self.selection == page_volume then
      self:change_volume(row,loopStart,loopEnder)
      if self.macro_record then 
        self:macro_add("oooooo_grid:change_volume("..row..","..loopStart..","..loopEnder..",false)")
      end
    elseif self.selection == page_pan then
      self:change_pan(row,loopStart,loopEnder)
      if self.macro_record then 
        self:macro_add("oooooo_grid:change_pan("..row..","..loopStart..","..loopEnder..",false)")
      end
    elseif self.selection == page_rate then
      self:change_rate(row,loopStart,loopEnder)
      if self.macro_record then 
        self:macro_add("oooooo_grid:change_rate("..row..","..loopStart..","..loopEnder..",false)")
      end
    elseif self.selection == page_frequency then
      self:change_filter(row,loopStart,loopEnder)
      if self.macro_record then 
        self:macro_add("oooooo_grid:change_filter("..row..","..loopStart..","..loopEnder..",false)")
      end
    elseif self.selection == page_tones then
      self:change_rate_ji(row,col)
      if self.macro_record then 
        self:macro_add("oooooo_grid:change_rate_ji("..row..","..col..",false)")
      end
    end
  elseif row==7 and on then 
    if self.selection > 1 then 
      self:change_selection_scale(col)
    else
      self:change_play_status(uS.loopNum,col)
    end
  elseif row==8 and on  then 
      self:change_selection(col)
  end
end

function Grido:change_play_status(i,col)
  if col==1 then 
    -- stop
    params:set(i.."stop trig",0)
    params:set(i.."stop trig",1)
  elseif col==2 then 
    -- play 
    params:set(i.."play trig",0)
    params:set(i.."play trig",1)
  elseif col==3 then 
    -- arm 
    params:set(i.."arming trig",0)
    params:set(i.."arming trig",1)
  elseif col==4 then 
    -- rec 
    params:set(i.."recording trig",0)
    params:set(i.."recording trig",1)
  end
end

function Grido:change_selection(selection)
  if selection == page_volume then 
    if not self.shown_text[page_volume] then
      self:show_text("volume")
      self.shown_text[page_volume] = true
    end
  elseif selection == page_pan then 
    if not self.shown_text[page_pan] then
      self:show_text("pan")
      self.shown_text[page_pan] = true
    end
  elseif selection == page_rate then 
    if not self.shown_text[page_rate] then
      self:show_text("rate")
      self.shown_text[page_rate] = true
    end
  elseif selection == page_frequency then 
    if not self.shown_text[page_frequency] then
      self:show_text("freq")
      self.shown_text[page_frequency] = true
    end
  elseif selection == page_tones then 
    if not self.shown_text[page_tones] then
      self:show_text("tone")
      self.shown_text[page_tones] = true
    end
  elseif selection == page_macro_record then 
    self:toggle_macro_record()
  elseif selection == page_macro_play then 
    self:toggle_macro_play()
  end
  if selection <= 6 then 
    self.selection = selection 
  end
end


function Grido:macro_add(fn_string)
  table.insert(self.macro_current,{fn=fn_string,time=self:current_time()})
end

function Grido:macro_check_reset()
  if self.pressed_buttons["8,8"]==true and self.pressed_buttons["8,7"]==true then
    self:toggle_macro_play(false)
    self:toggle_macro_record(false)
    -- clear macro
    self.macro_db = {}
    return true
  end 
  return false
end

function Grido:toggle_macro_play(on)
  print("toggle_macro_play")
  if on == nil then 
    if self:macro_check_reset() then 
      print("reseting")
      do return end 
    end
    on = not self.macro_play
  end
  if on and #self.macro_db == 0 then 
    on = false 
  end
  if on then 
    -- start co-routines of the macros
    for i,macro_chain in ipairs(self.macro_db) do
      print("starting macro "..i)
      self.macro_clock[i] = clock.run(function()
        while true do
          for _,macro in ipairs(macro_chain) do 
            print(macro.fn.." for "..macro.wait)
            local f= load(macro.fn)
            f()
            clock.sleep(macro.wait)
          end
        end
      end)  
    end
  else
    -- destroy the macro clocks
    for _,id in ipairs(self.macro_clock) do 
      clock.cancel(id)
    end
    self.macro_clock = {}
  end
  -- WORK
  self.macro_play = on 
end


function Grido:toggle_macro_record(on)
  print("toggle_macro_record")
  if on == nil then 
    if self:macro_check_reset() then 
      print("reseting")
      do return end 
    end
    on = not self.macro_record
  end
  if not on then 
    -- finish and add to the macro db
    local macro_new = {}
    local last_time = 0
    self:macro_add("done")
    local num_macros = #self.macro_current
    print("have "..(num_macros-1).." macros")
    if num_macros > 1 then
      for i,macro in ipairs(self.macro_current) do 
        if i < num_macros then 
          local m = {wait=self.macro_current[i+1].time-macro.time,fn=macro.fn}
          tab.print(m)
          table.insert(macro_new,m)
        end
      end
      table.insert(self.macro_db,macro_new)
    end
  else
    self:toggle_macro_play(false)
    self.macro_current = {}
  end
  self.macro_record = on 
end

function Grido:current_time()
  return clock.get_beat_sec()*clock.get_beats()
end


function Grido:change_selection_scale(selection)
  self.selection_scale = selection
  if self.selection == page_tones then
    -- change slew rate if on rate ji
    params:set("slew rate",util.linlin(1,self.grid_width,0.1,10,selection))
  end
end

function Grido:get_touch_points(row)
  local loopStart = 0 
  local loopEnder = 0 
  for i=1,self.grid_width do 
    if self.pressed_buttons[row..","..i]==true then 
      if loopStart == 0 then 
        loopStart = i
      else
        loopEnder = i
      end
    end
  end
  return loopStart,loopEnder
end

function Grido:change_volume(row,loopStart,loopEnder,update_loop)
  if loopEnder > 0 then 
    loopCenter = (loopStart+loopEnder)/2
    params:set(row.."vol",util.linlin(1,self.grid_width+1,0,1,loopCenter))
    params:set(row.."vol lfo amp",(loopEnder-loopStart)/(self.grid_width-1)/2)
    params:set(row.."vol lfo period",self.periods[self.selection_scale]+math.random(1,100)/100) 
    params:set(row.."vol lfo offset",math.random(10,60)/math.random(1,6)) 
  else
    params:set(row.."vol lfo amp",0)
    params:set(row.."vol",util.linlin(1,self.grid_width+1,0,1,loopStart))
  end
  if update_loop == nil or update_loop == true then
    uS.loopNum = row
    redraw()
  end
end

function Grido:change_pan(row,loopStart,loopEnder,update_loop)
  if loopEnder > 0 then 
    loopCenter = (loopStart+loopEnder)/2
    params:set(row.."pan",util.linlin(1,self.grid_width,-1,1,loopCenter))
    params:set(row.."pan lfo amp",(loopEnder-loopStart)/(self.grid_width-1))
    params:set(row.."pan lfo period",self.periods[self.selection_scale]+math.random(1,100)/100) 
    params:set(row.."pan lfo offset",math.random(10,60)/math.random(1,6)) 
  else
    params:set(row.."pan lfo amp",0)
    params:set(row.."pan",util.linlin(1,self.grid_width,-1,1,loopStart))
  end
  if update_loop == nil or update_loop == true then
    uS.loopNum = row
    redraw()
  end
end

function Grido:change_filter(row,loopStart,loopEnder,update_loop)
  if loopEnder > 0 then 
    loopCenter = (loopStart+loopEnder)/2
    params:set(row.."filter_frequency",util.linlin(1,self.grid_width,50,18000,loopCenter))
    params:set(row.."filter lfo amp",(loopEnder-loopStart)/(self.grid_width-1))
    params:set(row.."filter lfo period",self.periods[self.selection_scale]+math.random(1,100)/100) 
    params:set(row.."filter lfo offset",math.random(10,60)/math.random(1,6)) 
  else
    params:set(row.."filter lfo amp",0)
    params:set(row.."filter_frequency",util.linlin(1,self.grid_width,50,18000,loopStart))
  end
  if update_loop == nil or update_loop == true then
    uS.loopNum = row
    redraw()
  end
end

function Grido:change_rate(row,loopStart,loopEnder,update_loop)
  if loopEnder > 0 then 
    loopCenter = math.floor((loopStart+loopEnder)/2)
    params:set(row.."rate lfo center",self.rates_index[loopCenter])
    params:set(row.."rate lfo amp",(loopEnder-loopCenter)/(self.grid_width-1))
    params:set(row.."rate lfo period",self.periods[self.selection_scale]) 
    params:set(row.."rate lfo offset",math.random(10,60)/math.random(1,6)) 
  else
    params:set(row.."rate lfo amp",0)
  end
  params:set(row.."rate",self.rates_index[loopStart])
  if update_loop == nil or update_loop == true then
    uS.loopNum = row
    redraw()
  end
end

function Grido:change_rate_ji(row,col,update_loop)
  if col > 3 then 
    params:set(row.."rate tone",col-4)
  elseif col == 1 then 
    -- octave down
    self.current_octave[row]= util.clamp(self.current_octave[row]-1,1,#self.octave_index)
    params:set(row.."rate",self.octave_index[self.current_octave[row]])
  elseif col == 2 then 
    -- octave up
    self.current_octave[row] = util.clamp(self.current_octave[row]+1,1,#self.octave_index)
    params:set(row.."rate",self.octave_index[self.current_octave[row]])
  elseif col == 3 then 
    -- reverse
    params:set(row.."rate reverse",3-params:get(row.."rate reverse"))
  end
  if update_loop == nil or update_loop == true then
    uS.loopNum = row
    redraw()
  end
end

function Grido:change_loop(row,loopStart,loopEnder,update_loop)
  if loopEnder > 0 then 
    params:set(row.."start",(loopStart-1)/self.grid_width*self.loopMax)
    params:set(row.."length",(loopEnder-loopStart+1)/self.grid_width*self.loopMax)
  end
  softcut.position(row,(loopStart-1)/self.grid_width*self.loopMax+uC.bufferMinMax[row][2])
  if update_loop == nil or update_loop == true then
    uS.loopNum = row
    redraw()
  end
end

function Grido:get_visual()
  --- update the blinky thing
  self.blink_count=self.blink_count+1
  if self.blink_count>1000 then
    self.blink_count=0
  end
  for i,_ in ipairs(self.blinky) do
    if i==1 then
      self.blinky[i]=1-self.blinky[i]
    else
      if self.blink_count%i==0 then
        self.blinky[i]=0
      else
        self.blinky[i]=1
      end
    end
  end
  if self.show_graphic[2]>0 then
    self.show_graphic[2]=self.show_graphic[2]-1
  end

  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=0
    end
  end

  if self.show_graphic[2]>0 then
    local pixels=graphic_pixels.pixels(self.show_graphic[1])
    if pixels~=nil then
      for _,p in ipairs(pixels) do
        self.visual[p[1]+1][p[2]]=4
      end
    end
  end

  if self.selection == page_loops then
    -- show the current state for the loops
    for i=1,6 do
      -- get current position
      local colStart=params:get(i.."start")/self.loopMax*self.grid_width+1
      local colEnder=(params:get(i.."start")+params:get(i.."length"))/self.loopMax*self.grid_width
      local colPoser=(uP[i].position-uP[i].loopStart)/(uP[i].loopLength)*(colEnder-colStart+1)
      colStart = math.floor(colStart)
      colEnder = math.floor(colEnder)
      colPoser = math.floor(colPoser)+colStart
      if  tostring(colPoser) == "nan" then
        colPoser = 1
      end
      for j=colStart,colEnder do
        if i==uS.loopNum then 
          self.visual[i][j]=7
        else
          self.visual[i][j]=3
        end
      end
      self.visual[i][colPoser]=15
    end
    self.visual[7][1] = uP[uS.loopNum].isStopped and 15 or 0
    self.visual[7][2] = uP[uS.loopNum].isStopped and 0 or 15
    self.visual[7][3] = uS.recording[uS.loopNum] == 1 and 15 or 0
    self.visual[7][4] = uS.recording[uS.loopNum] == 2 and 15 or 0
  elseif self.selection == page_volume then 
    -- show current volume for the loops
    for i=1,6 do 
        self.visual[i][util.round(uP[i].vol*self.grid_width)+1] = 15
    end
  elseif self.selection == page_pan then 
    -- show current pan for the loops
    for i=1,6 do 
        self.visual[i][util.round(util.linlin(-1,1,1,self.grid_width,uP[i].pan),1)] = 15
    end
  elseif self.selection == page_rate then 
    -- show current rate for the loops
    for i=1,6 do 
      local closestRate = {1,10000}
      for j,rate in ipairs(self.rates) do
        local diff = math.abs(100*uP[i].rate-rate)
        if diff < closestRate[2] then 
          closestRate = {j,diff}
        end
      end
      self.visual[i][closestRate[1]] = 15
    end
  elseif self.selection == page_frequency then 
    -- show current filter fc for the loops
    for i=1,6 do 
        self.visual[i][util.round(util.linlin(50,18000,1,self.grid_width,uP[i].fc),1)] = 15
    end
  elseif self.selection == page_tones then 
    -- show current rate ji for the loops
    for i=1,6 do 
        self.visual[i][params:get(i.."rate tone")+4] = 15
        -- show current octave
        local closestIndex = {1,10000}
        for j,index in ipairs(self.octave_index) do
          local diff = math.abs(params:get(i.."rate")-index)
          if diff < closestIndex[2] then 
            closestIndex = {j,diff}
          end
        end
        self.visual[i][1]=closestIndex[1]*2
        self.visual[i][2]=closestIndex[1]*2
        if params:get(i.."rate reverse") == 1 then 
          self.visual[i][3]=15
        end
    end
  end

  if self.macro_record then 
    self.visual[8][page_macro_record] = 15
  else
    self.visual[8][page_macro_record] = 4
  end

  if self.macro_play then 
    self.visual[8][page_macro_play] = 15
  else
    self.visual[8][page_macro_play] = 4
  end

  -- show lfo period scale if selection > 1
  if self.selection ~= page_loops   then 
    for i=1,self.grid_width do
      self.visual[7][i]=i-1
    end
    self.visual[7][self.selection_scale]=15*self.blinky[self.grid_width+1-self.selection_scale]
  end

  -- illuminate selection 
  self.visual[8][self.selection] = 15 

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    row,col=k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)]=15
  end

  return self.visual
end

function Grido:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  for row=1,8 do
    for col=1,self.grid_width do
      if gd[row][col]~=0  then
        self.g:led(col,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

function Grido:show_text(text,time)
  print("show_text "..text)
  if time==nil then
    time=40
  end
  self.show_graphic={text,time}
end


return Grido
