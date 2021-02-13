-- grido

local Grido={}

local rates = {-400,-200,-150,-100,-75,-50,-25,-12.5,12.5,25,50,75,100,150,200,400}
local periods = {96,48,24,12,10,8,6,4,3.2,2.4,1.6,1.2,0.8,0.4,0.2,0.1}

function Grido:new(args)
  local m=setmetatable({},{__index=Grido})
  local args=args==nil and {} or args

  -- selection 
  m.selection = 1
  m.selection_lfo = 1

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
      self:change_rate(row)
    end
  elseif row==7 and on then 
    if self.selection > 1 then 
      self:change_lfo(col)
    end
  elseif row==8 and on  then 
      self:change_selection(col)
  end
end

function Grido:change_selection(selection)
  if selection <= 2 then 
    self.selection = selection 
  end
end

function Grido:change_lfo(selection)
  self.selection_lfo = selection
end

function Grido:change_rate(row)
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
  if loopEnder > 0 then 
    loopCenter = math.floor((loopStart+loopEnder)/2)
    params:set(row.."rate lfo center",loopCenter)
    params:set(row.."rate lfo amp",(loopEnder-loopCenter)/16)
    params:set(row.."rate lfo period",periods[self.selection_lfo]) 
  else
    params:set(row.."rate lfo amp",0)
  end
  params:set(row.."rate",loopStart)
end

function Grido:change_loop(row)
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

  -- clear visual
  for row=1,8 do
    for col=1,16 do
      self.visual[row][col]=0
    end
  end

  if self.selection == 1 then
    -- get the current state for the loops
    for i=1,6 do
      -- get current position
      local colStart=params:get(i.."start")/self.loopMax*16+1
      local colEnder=(params:get(i.."start")+params:get(i.."length"))/self.loopMax*16
      local colPoser=(uP[i].position-uP[i].loopStart)/(uP[i].loopLength)*(colEnder-colStart+1)
      colStart = math.floor(colStart)
      colEnder = math.floor(colEnder)
      colPoser = math.floor(colPoser)+colStart
      for j=colStart,colEnder do
        self.visual[i][j]=5
      end
      self.visual[i][colPoser]=15
    end
  elseif self.selection == 2 then 
    -- set current rate for the loops
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
  end

  -- show lfo period scale if selection > 1
  if self.selection > 1 then 
    for i=1,16 do
      self.visual[7][i]=i-1
    end
    self.visual[7][self.selection_lfo]=15*self.blinky[17-self.selection_lfo]
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

return Grido
