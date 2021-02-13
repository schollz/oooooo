-- grido
local json=include("oooooo/lib/json")
local graphic_pixels=include("oooooo/lib/glyphs")

local Grido={}

-- copied from ooooooo
local rates = {-400,-200,-150,-100,-75,-50,-25,-12.5,12.5,25,50,75,100,150,200,400}
local octave_index = {9,10,11,13,15,16}
local periods = {96,48,24,12,10,8,6,4,3.2,2.4,1.6,1.2,0.8,0.4,0.2,0.1}

function Grido:new(args)
  local m=setmetatable({},{__index=Grido})
  local args=args==nil and {} or args

  -- selection 
  m.selection = 1
  m.selection_scale = 10
  m.current_octave = {4,4,4,4,4,4}
  m.show_graphic = {nil,0}
  m.selected_loop = 1

  -- setup visual
  m.visual={}
  for i=1,8 do
    m.visual[i]={}
    for j=1,16 do
      m.visual[i][j]=0
    end
  end

  -- debouncing and blinking
  m.blink_count=0
  m.blinky={}
  for i=1,16 do
    m.blinky[i]=1 -- 1 = fast, 16 = slow
  end

  -- grid uses pre-defined max loop length
  m.loopMax=(60/clock.get_tempo())*params:get("start length")

  m.pressed_buttons={}
  -- initiate the grid
  -- grid specific
  m.g=grid.connect()
  m.g.key=function(x,y,z)
    m:grid_key(x,y,z)
  end
  print("grid columns: "..m.g.cols)

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.05
  m.grid_refresh.event=function()
    m:grid_redraw()
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
    if self.selection == 1 then 
      self:change_loop(row)
    elseif self.selection == 2 then
      self:change_volume(row)
    elseif self.selection == 3 then
      self:change_pan(row)
    elseif self.selection == 4 then
      self:change_rate(row)
    elseif self.selection == 5 then
      self:change_filter(row)
    elseif self.selection == 6 then
      self:change_rate_ji(row,col)
    end
  elseif row==7 and on then 
    if self.selection > 1 then 
      self:change_selection_scale(col)
    else
      self:change_play_status(self.selected_loop,col)
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
  if selection == 2 then 
    self:show_text("volume")
  elseif selection == 3 then 
    self:show_text("pan")
  elseif selection == 4 then 
    self:show_text("rate")
  elseif selection == 5 then 
    self:show_text("freq")
  elseif selection == 6 then 
    self:show_text("tone")
  end
  if selection <= 6 then 
    self.selection = selection 
  end
end

function Grido:change_selection_scale(selection)
  self.selection_scale = selection
  if self.selection == 5 then
    -- change slew rate if on rate ji
    params:set("slew rate",util.linlin(1,16,0.1,10,selection))
  end
end

function Grido:get_touch_points(row)
  local loopStart = 0 
  local loopEnder = 0 
  for i=1,16 do 
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

function Grido:change_volume(row)
  loopStart,loopEnder = self:get_touch_points(row)
  if loopEnder > 0 then 
    loopCenter = (loopStart+loopEnder)/2
    params:set(row.."vol",(loopCenter)/15)
    params:set(row.."vol lfo amp",(loopEnder-loopStart)/15/2)
    params:set(row.."vol lfo period",periods[self.selection_scale]) 
  else
    params:set(row.."vol lfo amp",0)
    params:set(row.."vol",(loopStart-1)/15)
  end
end

function Grido:change_pan(row)
  loopStart,loopEnder = self:get_touch_points(row)
  if loopEnder > 0 then 
    loopCenter = (loopStart+loopEnder)/2
    params:set(row.."pan",util.linlin(1,16,-1,1,loopCenter))
    params:set(row.."pan lfo amp",(loopEnder-loopStart)/15)
    params:set(row.."pan lfo period",periods[self.selection_scale]) 
  else
    params:set(row.."pan lfo amp",0)
    params:set(row.."pan",util.linlin(1,16,-1,1,loopStart))
  end
end

function Grido:change_filter(row)
  loopStart,loopEnder = self:get_touch_points(row)
  if loopEnder > 0 then 
    loopCenter = (loopStart+loopEnder)/2
    params:set(row.."filter_frequency",util.linlin(1,16,50,18000,loopCenter))
    params:set(row.."filter lfo amp",(loopEnder-loopStart)/15)
    params:set(row.."filter lfo period",periods[self.selection_scale]) 
  else
    params:set(row.."filter lfo amp",0)
    params:set(row.."filter_frequency",util.linlin(1,16,50,18000,loopStart))
  end
end

function Grido:change_rate(row)
  loopStart,loopEnder = self:get_touch_points(row)
  if loopEnder > 0 then 
    loopCenter = math.floor((loopStart+loopEnder)/2)
    params:set(row.."rate lfo center",loopCenter)
    params:set(row.."rate lfo amp",(loopEnder-loopCenter)/15)
    params:set(row.."rate lfo period",periods[self.selection_scale]) 
  else
    params:set(row.."rate lfo amp",0)
  end
  params:set(row.."rate",loopStart)
end

function Grido:change_rate_ji(row,col)
  if col > 4 then 
    params:set(row.."rate tone",col-5)
  elseif col == 2 then 
    -- octave down
    self.current_octave[row]= util.clamp(self.current_octave[row]-1,1,#octave_index)
    params:set(row.."rate",octave_index[self.current_octave[row]])
  elseif col == 3 then 
    -- octave up
    self.current_octave[row] = util.clamp(self.current_octave[row]+1,1,#octave_index)
    params:set(row.."rate",octave_index[self.current_octave[row]])
  elseif col == 4 then 
    -- reverse
    params:set(row.."rate reverse",3-params:get(row.."rate reverse"))
  end
end

function Grido:change_loop(row)
  self.selected_loop = row 
  loopStart,loopEnder = self:get_touch_points(row)
  if loopEnder > 0 then 
    params:set(row.."start",(loopStart-1)/16*self.loopMax)
    params:set(row.."length",(loopEnder-loopStart+1)/16*self.loopMax)
  end
  softcut.position(row,(loopStart-1)/16*self.loopMax+uC.bufferMinMax[row][2])
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
    for col=1,16 do
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

  if self.selection == 1 then
    -- show the current state for the loops
    for i=1,6 do
      -- get current position
      local colStart=params:get(i.."start")/self.loopMax*16+1
      local colEnder=(params:get(i.."start")+params:get(i.."length"))/self.loopMax*16
      local colPoser=(uP[i].position-uP[i].loopStart)/(uP[i].loopLength)*(colEnder-colStart+1)
      colStart = math.floor(colStart)
      colEnder = math.floor(colEnder)
      colPoser = math.floor(colPoser)+colStart
      for j=colStart,colEnder do
        if i==self.selected_loop then 
          self.visual[i][j]=7
        else
          self.visual[i][j]=3
        end
      end
      self.visual[i][colPoser]=15
    end
    self.visual[7][1] = uP[self.selected_loop].isStopped and 15 or 0
    self.visual[7][2] = uP[self.selected_loop].isStopped and 0 or 15
    self.visual[7][3] = uS.recording[self.selected_loop] == 1 and 15 or 0
    self.visual[7][4] = uS.recording[self.selected_loop] == 2 and 15 or 0
  elseif self.selection == 2 then 
    -- show current volume for the loops
    for i=1,6 do 
        self.visual[i][util.round(uP[i].vol*15,1)+1] = 15
    end
  elseif self.selection == 3 then 
    -- show current pan for the loops
    for i=1,6 do 
        self.visual[i][util.round(util.linlin(-1,1,1,16,uP[i].pan),1)] = 15
    end
  elseif self.selection == 4 then 
    -- show current rate for the loops
    for i=1,6 do 
      if params:get(i.."rate lfo amp") > 0 and params:get(i.."rate lfo period") > 0 then 
        local closestRate = {1,10000}
        for j,rate in ipairs(rates) do
          local diff = math.abs(100*uP[i].rate-rate)
          if diff < closestRate[2] then 
            closestRate = {j,diff}
          end
        end
        self.visual[i][closestRate[1]] = 15
      else
        self.visual[i][params:get(i.."rate")] = 15
      end
    end
  elseif self.selection == 5 then 
    -- show current filter fc for the loops
    for i=1,6 do 
        self.visual[i][util.round(util.linlin(50,18000,1,16,uP[i].fc),1)] = 15
    end
  elseif self.selection == 6 then 
    -- show current rate ji for the loops
    for i=1,6 do 
        self.visual[i][params:get(i.."rate tone")+5] = 15
        -- show current octave
        local closestIndex = {1,10000}
        for j,index in ipairs(octave_index) do
          local diff = math.abs(params:get(i.."rate")-index)
          if diff < closestIndex[2] then 
            closestIndex = {j,diff}
          end
        end
        self.visual[i][1]=closestIndex[1]*2
        if params:get(i.."rate reverse") == 1 then 
          self.visual[i][4]=15
        end
    end
  end

  -- show lfo period scale if selection > 1
  if self.selection ~= 1 and self.selection ~= 7   then 
    for i=1,16 do
      self.visual[7][i]=i-1
    end
    self.visual[7][self.selection_scale]=15*self.blinky[17-self.selection_scale]
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
    for col=1,16 do
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
