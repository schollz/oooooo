-- hoooooops v0.1
-- six persistant autonomous tapes
--
-- llllllll.co/t/hoops
--
--
--
--    ▼ instructions below ▼
--
-- K1 shifts
-- K2 stops
-- K2 again resets loop
-- K3 plays
-- shift+K2 clears
-- shift+K3 records
-- E1 changes loops
-- E2 selects parameters
-- E3 adjusts parameters
--

local json=import "json"

-- user parameters
uP={
  -- initialized in init
}

-- user state
uS={
  updateUI=false,
  updateParams=0,
  updateTape=false,
  shift=false,
  loopNum=1,-- 0 = all loops
  selectedPar=1,
}

-- user constants
uC={
  bufferMinMax={
    {1,1,80},
    {1,81,160},
    {1,161,240},
    {2,1,80},
    {2,81,160},
    {2,161,240},
  },
  loopMinMax={1,78},
  radiiMinMax={10,40},
  widthMinMax={8,120},
  heightMinMax={20,60},
  centerOffsets={
    {1,-2},
    {2,0},
    {1,2},
    {-1,2},
    {-2,0},
    {-1,-2},
  },
  parms={"loopstart","loopend","vol","rate","pan"},
}

PATH=_path.audio..'hoops/'

function init()
  -- initialize user parameters
  for i=1,7 do
    uP[i]={}
    uP[i].position=0
    uP[i].loopStart=0
    uP[i].loopLength=uC.loopMinMax[2]-uC.loopMinMax[1]
    uP[i].isStopped=true
    uP[i].isRecording=false
    uP[i].vol=1
    uP[i].rate=1
    uP[i].pan=0
  end
  
  -- make data directory
  if not util.file_exists(PATH) then util.make_dir(PATH) end
  
  -- load buffer from file
  if util.file_exists(PATH.."hoops.wav") then
    softcut.buffer_read_stereo(PATH.."hoops.wav",0,0,-1)
  end
  
  -- load parameters from file
  if util.file_exists(PATH.."hoops.json") then
    uP=json.parse(readAll(PATH.."hoops.json"))
  end
  
  -- update softcut
  for i=1,6 do
    softcut.level(i,1)
    softcut.level_input_cut(1,i,1)
    softcut.level_input_cut(2,i,1)
    softcut.pan(i,0)
    softcut.play(i,0)
    softcut.rate(i,1)
    softcut.loop_start(i,uC.bufferMinMax[i][2])
    softcut.loop_end(i,uC.bufferMinMax[i][3])
    softcut.loop(i,1)
    softcut.rec(i,0)
    
    softcut.fade_time(i,0.01)
    softcut.level_slew_time(i,0.5)
    softcut.rate_slew_time(i,0.5)
    
    softcut.rec_level(i,1)
    softcut.pre_level(i,1)
    softcut.position(i,uC.bufferMinMax[i][2])
    softcut.buffer(i,uC.bufferMinMax[i][1])
    softcut.enable(i,1)
  end
  
  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=0.05
  timer.count=-1
  timer.event=update_timer
  timer:start()
  
  -- initialize timer for updating parameters
  -- and tape on disk
  filewriter=metro.init()
  filewriter.time=0.1
  filewriter.count=-1
  filewriter.event=update_parameter_file
  filewriter:start()
  
  -- position poll
  softcut.phase_quant(1,0.025)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
  -- TODO: experiment with record priming
  -- and starting on incoming audio
  -- set time low when primed, set time high when done
  -- p_amp_in=poll.set("amp_in_l")
  -- p_amp_in.time=0.1
  -- p_amp_in.callback=function(val)
  --   print(val)
  -- end
  -- p_amp_in:start()
end

--
-- updaters
--
function update_positions(i,x)
  -- adjust position so it is relative to loop start
  -- TODO: check that this is right
  uP[i].position=x-uP[i].loopStart-uC.bufferMinMax[i][2]
  uS.updateUI=true
end

function update_timer()
  if uS.updateUI then
    redraw()
  end
end

function update_parameter_file()
  if uS.updateParams>0 then
    uS.updateParams=uS.updateParams-1
    if uS.updateParams==0 then
      -- write file
      file=io.open(PATH.."hoops.json","w+")
      io.output(file)
      io.write(json.stringify(uP))
      io.close(file)
    end
  end
  if uS.updateTape then
    -- save tape
    softcut.buffer_write_stereo(PATH.."hoops.wav",0,-1)
  end
end

--
-- tape functions
--
function tape_stop_reset(n)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if uP[i].isStopped then
      -- reset to 0 position
      if uP[i].position~=0 then
        -- move to beginning of loop
        uP[i].position=0
        softcut.position(j,uP[i].position+uC.bufferMinMax[i][2]+uP[i].loopStart)
      end
    else
      -- stop playing
      softcut.rate(i,0)
      softcut.play(i,0)
      uP[i].isStopped=true
    end
  end
end

function tape_clear(n)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    softcut.buffer_clear_region_channel(
      uC.bufferMinMax[i][1],
      uC.bufferMinMax[i][2],
      uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2],
    )
  end
end

function tape_play(n)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if uP[i].isRecording then
      -- stop recording, if recording
      uP[i].isRecording=false
      softcut.rec(i,0)
    end
    -- start playing
    softcut.rate(i,uP[i].rate)
    softcut.play(i,1)
    uP[i].isStopped=false
  end
end

function tape_rec(n)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if uP[i].isStopped then
      softcut.play(i,1)
      uP[i].isStopped=false
    end
    -- start recording
    softcut.rec(i,1)
    uP[i].isRecording=true
  end
end

function tape_change_loop(n,lstart,llength)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if lstart>0 then
      uP[i].loopStart=lstart
    end
    if llength>0 then
      uP[i].loopLength=llength
    end
    if uP[i].loopLength+uP[i].loopStart>uC.loopMinMax[2] then
      -- loop length is too long, shorten it
      uP[i].loopLength=uC.loopMinMax[2]-uP[i].loopStart
    end
    -- move to start of loop if position is outside of loop
    if uP[i].position<uP[i].loopStart or uP[i].position>uP[i].loopStart+uP[i].loopLength then
      uP[i].position=uP[i].loopStart
      softcut.position(i,uP[i].position+uC.bufferMinMax[i][2])
    end
    sofcut.loop_start(i,1+uP[i].loopStart+uC.bufferMinMax[i][2])
    sofcut.loop_end(i,uP[i].loopStart+uC.bufferMinMax[i][2]+uP[i].loopLength)
  end
  uS.updateParams=uS.updateParams+1
end

function tape_update_volume(n,x)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    uP[i].vol=x
    softcut.level(i,x)
  end
  uS.updateParams=uS.updateParams+1
end

function tape_update_rate(n,x)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    uP[i].rate=x
    softcut.rate(i,x)
  end
  uS.updateParams=uS.updateParams+1
end

function tape_update_pan(n,x)
  i1=n
  i2=n
  if n==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    uP[i].pan=x
    softcut.pan(i,x)
  end
  uS.updateParams=uS.updateParams+1
end

--
-- encoders
--
function enc(n,d)
  if n==1 then
    uS.loopNum=util.clamp(uS.loopNum+d,1,7)
  elseif n==2 then
    uS.selectedPar=utils.clamp(uS.selectedPar+d,1,5)
  elseif n==3 then
    if uS.selectedPar==1 then
      uP[uS.loopNum].loopStart=util.clamp(uP[uS.loopNum].loopStart+d/10,0,uC.loopMinMax[2])
      tape_change_loop(uS.loopNum,uP[uS.loopNum],0)
    elseif uS.selectedPar==2 then
      uP[uS.loopNum].loopLength=util.clamp(uP[uS.loopNum].loopLength+d/10,0,uC.loopMinMax[2])
      tape_change_loop(uS.loopNum,0,uP[uS.loopNum].loopLength)
    elseif uS.selectedPar==3 then
      uP[uS.loopNum].vol=util.clamp(uP[uS.loopNum].vol+d/100,0,1)
      tape_update_volume(uS.loopNum,uP[uS.loopNum].vol)
    elseif uS.selectedPar==4 then
      uP[uS.loopNum].rate=util.clamp(uP[uS.loopNum].rate+d/10,-4,4)
      tape_update_rate(uS.loopNum,uP[uS.loopNum].rate)
    elseif uS.selectedPar==5 then
      uP[uS.loopNum].pan=util.clamp(uP[uS.loopNum].pan+x/10,-1,1)
      tape_update_pan(uS.loopNum,uP[uS.loopNum].pan)
    end
  end
  uS.updateUI=true
end

function key(n,z)
  if n==1 then
    uS.shift=z
  elseif n==2 and z==1 then
    if uS.shift then
      tape_clear(uS.loopNum)
    else
      tape_stop_reset(uS.loopNum)
    end
  elseif n==3 and z==1 then
    if uS.shift then
      tape_rec(uS.loopNum)
    else
      tape_play(uS.loopNum)
    end
  end
  uS.updateUI=true
end

--
-- screen
--
function redraw()
  uS.updateUI=false
  screen.clear()
  
  -- check shift
  shift_amount=0
  if state.shift then
    shift_amount=4
  end
  
  -- show header
  screen.move(2+shift_amount,8+shift_amount)
  screen.text("hoooooops")
  
  -- show recording symbol
  if uP[uS.loopNum].isRecording then
    screen.move(70,8)
    screen.text("REC")
  end
  
  -- show loop info
  x=2
  y=16
  screen.move(x,y)
  if uS.loopNum==7 then
    screen.text("all")
  else
    screen.text(uS.loopNum)
  end
  
  screen.move(x+16,y)
  if uS.selectedPar==1 then
    screen.level(15)
  else
    screen.level(5)
  end
  screen.text(uP[uS.loopNum].loopStart)
  
  screen.move(x+20,y)
  screen.level(5)
  screen.text("-")
  
  screen.move(x+28,y)
  if uS.selectedPar==2 then
    screen.level(15)
  else
    screen.level(5)
  end
  screen.text(uP[uS.loopNum].loopLength)
  
  screen.move(x+32,y)
  screen.level(5)
  screen.text("s")
  
  screen.move(x+38,y)
  if uS.selectedPar==3 then
    screen.level(15)
  else
    screen.level(5)
  end
  screen.text(uP[uS.loopNum].vol)
  
  screen.move(x+44,y)
  if uS.selectedPar==4 then
    screen.level(15)
  else
    screen.level(5)
  end
  screen.text(uP[uS.loopNum].rate)
  
  screen.move(x+55,y)
  if uS.selectedPar==5 then
    screen.level(15)
  else
    screen.level(5)
  end
  screen.text(uP[uS.loopNum].pan)
  
  -- draw representation of current loop states
  for i=1,6 do
    -- draw circles
    screen.level(15)
    r=(uC.radiiMinMax[2]-uC.radiiMinMax[1])*uP[i].vol+uC.radiiMinMax[1]
    x=uC.centerOffsets[i][1]+(uC.widthMinMax[2]-uC.heightMinMax[1])*(uP[i].pan+1)/2+uC.widthMinMax[1]
    y=uC.centerOffsets[i][2]+(uC.heightMinMax[2]-uC.widthMinMax[1])*(uP[i].rate+4)/8+uC.heightMinMax[1]
    if uS.loopNum==7 or uS.loopNum==i then
      screen.line_width(2)
    else
      screen.line_width(1)
    end
    screen.circle(x,y,r)
    screen.stroke()
    
    -- draw arc at position
    angle=360*(uP[i].position/uP[i].loopLength)
    screen.arc(x,y,r,angle-5,angle+5)
    screen.stroke()
  end
  
  screen.update()
end

--
-- utils
--
function readAll(file)
  local f=assert(io.open(file,"rb"))
  local content=f:read("*all")
  f:close()
  return content
end
