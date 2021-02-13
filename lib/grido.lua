-- grido

local Grido={}

function Grido:new(args)
  local m=setmetatable({},{__index=Grido})
  local args=args==nil and {} or args

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

  if row <= 6 then 
    if on then 
      self:change_loop(row)
    end
  end
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


  loopStart = util.linlin(1,16,0,self.loopMax,loopStart)
  params:set(row.."start",loopStart)
  if loopEnder > 0 then 
    loopEnder = util.linlin(1,16,0,self.loopMax,loopEnder)
    params:set(row.."length",loopEnder-loopStart)
  else
    params:delta(row.."reset trig",1)
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

  -- clear visual
  for row=1,8 do
    for col=1,16 do
      self.visual[row][col]=0
    end
  end

  -- get the current state for the loops
  for i=1,6 do
    local row=i
    -- get current position
    local colStart=util.linlin(uC.bufferMinMax[i][2],uC.bufferMinMax[i][2]+self.loopMax,1,16,uP[i].loopStart+uC.bufferMinMax[i][2])
    local colEnder=util.linlin(uC.bufferMinMax[i][2],uC.bufferMinMax[i][2]+self.loopMax,1,16,uP[i].loopStart+uP[i].loopLength+uC.bufferMinMax[i][2])
    local colPoser=util.linlin(uC.bufferMinMax[i][2],uC.bufferMinMax[i][2]+self.loopMax,1,16,uP[i].position+uC.bufferMinMax[i][2])
    for col=colStart,colEnder do
      self.visual[row][col]=5
    end
    self.visual[row][colPoser]=15
  end

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    row,col=k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)]=15
  end
end

function Grido:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  rows=#gd
  cols=#gd[1]
  for row=1,rows do
    for col=1,cols do
      if gd[row][col]~=0 then
        self.g:led(col,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

return Grid
