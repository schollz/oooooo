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

local json=include "lib/json"

-- user parameters
uP={
  -- initialized in init
}

-- user state
uS={
  clearing=0,-- 1, clears current, 2 clears all
  recording=0,-- 0 = not recording, 1 = armed, 2 = recording
  recordingTime=0,
  updateUI=false,
  updateParams=0,
  updateTape=false,
  loopCleared=false,
  isCleared=true,
  shift=false,
  loopNum=1,-- 7 = all loops
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
  radiiMinMax={4,180},
  widthMinMax={8,124},
  heightMinMax={12,64},
  centerOffsets={
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    -- {3*1,3*-2},
    -- {3*2,0},
    -- {3*1,3*2},
    -- {3*-1,3*2},
    -- {3*-2,0},
    -- {3*-1,3*-2},
  },
  parms={"loopstart","loopend","vol","rate","pan"},
  updateTimerInterval=0.05,
}

PATH=_path.audio..'hoops/'

function init()
  init_loops(7)
  
  -- make data directory
  if not util.file_exists(PATH) then util.make_dir(PATH) end
  
  -- load buffer from file
  -- if util.file_exists(PATH.."hoops.wav") then
  --   softcut.buffer_read_stereo(PATH.."hoops.wav",0,0,-1)
  -- end
  
  -- -- load parameters from file
  -- if util.file_exists(PATH.."hoops.json") then
  --   filecontents=readAll(PATH.."hoops.json")
  --   print(filecontents)
  --   uP=json.parse(filecontents)
  -- end
  
  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=updateTimerInterval
  timer.count=-1
  timer.event=update_timer
  timer:start()
  
  -- -- initialize timer for updating parameters
  -- -- and tape on disk
  -- filewriter=metro.init()
  -- filewriter.time=0.25
  -- filewriter.count=-1
  -- filewriter.event=update_parameter_file
  -- filewriter:start()
  
  -- position poll
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
  -- TODO: experiment with record priming
  -- and starting on incoming audio
  -- set time low when primed, set time high when done
  p_amp_in=poll.set("amp_in_l")
  p_amp_in.time=1
  p_amp_in.callback=function(val)
    if uS.recording==1 then
      print(val)
      if val>0.003 then
        uS.recording==2
        tape_rec(uS.loopNum)
      end
    end
  end
  p_amp_in:start()
  
  redraw()
end

function init_loops(i)
  print("initializing  "..i)
  uP[i]={}
  uP[i].loopStart=0
  uP[i].position=uP[i].loopStart
  uP[i].loopLength=2*i
  uP[i].isStopped=true
  uP[i].vol=0.5
  uP[i].rate=1
  uP[i].pan=0
  
  -- update softcut
  softcut.level(i,1)
  softcut.level_input_cut(1,i,1)
  softcut.level_input_cut(2,i,1)
  softcut.pan(i,0)
  softcut.play(i,0)
  softcut.rate(i,1)
  softcut.loop_start(i,uC.bufferMinMax[i][2])
  softcut.loop_end(i,uC.bufferMinMax[i][2]+uP[i].loopLength)
  softcut.loop(i,1)
  softcut.rec(i,0)
  
  softcut.fade_time(i,0.01)
  softcut.level_slew_time(i,0.2)
  softcut.rate_slew_time(i,0.2)
  
  softcut.rec_level(i,1)
  softcut.pre_level(i,1)
  softcut.position(i,uC.bufferMinMax[i][2])
  softcut.buffer(i,uC.bufferMinMax[i][1])
  softcut.enable(i,1)
  softcut.phase_quant(i,0.025)
end

--
-- updaters
--
function update_positions(i,x)
  -- adjust position so it is relative to loop start
  uP[i].position=x-uC.bufferMinMax[i][2]
  uS.updateUI=true
end

function update_timer()
  if uS.updateUI then
    redraw()
  end
  if uS.recording==2 then
    uS.recordingTime=uS.recordingTime+updateTimerInterval
    if uS.recordingTime>=uP[i].loopLength then
      -- stop recording
      tape_stop_rec(uS.loopNum)
    end
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
function tape_reset_clear(j)
  -- if uS.loopNum == 7 then stop all
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if uP[i].isStopped then
      tape_reset(i)
    else
      tape_stop(i)
    end
  end
end

function tape_reset(i)
  print("tape_reset "..i)
  uP[i].position=0
  softcut.position(i,uC.bufferMinMax[i][2]+uP[i].loopStart)
end

function tape_stop(i)
  print("tape_stop "..i)
  if uS.recording>0 then
    tape_stop_rec(i)
  end
  softcut.rate(i,0)
  softcut.play(i,0)
  uP[i].isStopped=true
end

function tape_stop_rec(i)
  p_amp_in.time=1
  uS.recording=0
  uS.recordingTime=0
  --   -- slowly stop
  -- for j=1,10 do
  --   softcut.rec(i,(10-j)/10)
  --   sleep(0.05)
  -- end
  softcut.rec(i,0)
end

function tape_clear(j)
  print("tape_clear "..j)
  -- prevent double clear
  if uS.loopCleared and j~=7 then
    do return end
  end
  -- signal clearing
  uS.loopCleared=true
  redraw()
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    softcut.buffer_clear_region_channel(
      uC.bufferMinMax[i][1],
      uC.bufferMinMax[i][2],
    uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2])
    -- reinitialize
    init_loops(i)
  end
  sleep(0.5)
  uS.loopCleared=false
  redraw()
  uS.isCleared=true
end

function tape_play(i)
  print("tape_play "..i)
  if uS.recording>0 then
    tape_stop_rec(i)
  end
  softcut.play(i,1)
  softcut.rate(i,uP[i].rate)
  uP[i].isStopped=false
end

function tape_arm_rec(i)
  print("arming recording "..n)
  -- arm  recording
  uS.recording=1
  -- monitor input
  p_amp_in.time=0.05
  redraw()
end

function tape_rec(i)
  print("starting recording on "..i)
  if uP[i].isStopped then
    tape_play(i)
  end
  p_amp_in.time=1
  uS.isCleared=false
  uS.recordingTime=0
  uS.recording=2 -- recording is live
  softcut.rec_level(i,1)
  softcut.pre_level(i,1)
  softcut.rec(i,1)
  redraw()
end

function tape_change_loop(i)
  print("tape_change_loop on "..i)
  if uP[i].loopLength+uP[i].loopStart>uC.loopMinMax[2] then
    -- loop length is too long, shorten it
    uP[i].loopLength=uC.loopMinMax[2]-uP[i].loopStart
  end
  -- move to start of loop if position is outside of loop
  if uP[i].position<uP[i].loopStart or uP[i].position>uP[i].loopStart+uP[i].loopLength then
    uP[i].position=uP[i].loopStart
    softcut.position(i,uP[i].position+uC.bufferMinMax[i][2])
  end
  softcut.loop_start(i,uP[i].loopStart+uC.bufferMinMax[i][2])
  softcut.loop_end(i,uP[i].loopStart+uC.bufferMinMax[i][2]+uP[i].loopLength)
end

--
-- encoders
--
function enc(n,d)
  if n==1 and uS.recording==0 then
    -- do not allow changing loops if recording
    uS.loopNum=util.clamp(uS.loopNum+d,1,7)
  elseif n==2 then
    uS.selectedPar=util.clamp(uS.selectedPar+d,1,5)
  elseif n==3 and uS.loopNum~=7 then
    if uS.selectedPar==1 then
      uP[uS.loopNum].loopStart=util.clamp(uP[uS.loopNum].loopStart+d/10,0,uC.loopMinMax[2])
      tape_change_loop(uS.loopNum)
    elseif uS.selectedPar==2 then
      uP[uS.loopNum].loopLength=util.clamp(uP[uS.loopNum].loopLength+d/10,uC.loopMinMax[1],uC.loopMinMax[2])
      tape_change_loop(uS.loopNum)
    elseif uS.selectedPar==3 then
      uP[uS.loopNum].vol=util.clamp(uP[uS.loopNum].vol+d/100,0,1)
      softcut.level(uS.loopNum,uP[uS.loopNum].vol)
    elseif uS.selectedPar==4 then
      uP[uS.loopNum].rate=util.clamp(uP[uS.loopNum].rate+d/100,-4,4)
      softcut.rate(uS.loopNum,uP[uS.loopNum].rate)
    elseif uS.selectedPar==5 then
      uP[uS.loopNum].pan=util.clamp(uP[uS.loopNum].pan+d/100,-1,1)
      softcut.pan(uS.loopNum,uP[uS.loopNum].pan)
    end
  end
  uS.updateUI=true
end

function key(n,z)
  if n==1 then
    uS.shift=not uS.shift
  elseif n==2 and z==1 then
    if uS.shift then
      if uS.isCleared then
        -- clear all
        tape_clear(7)
      else
        -- clear current
        tape_clear(uS.loopNum)
      end
    else
      tape_reset_clear(uS.loopNum)
    end
  elseif n==3 and z==1 then
    if uS.shift and uS.loopNum~=7 then
      if uS.recording==0 then
        tape_arm_rec(uS.loopNum)
      elseif uS.recording==1 then
        tape_rec(uS.loopNum)
      end
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
  if uS.shift then
    shift_amount=4
  end
  
  -- show header
  screen.level(15)
  
  -- show recording symbol
  screen.move(116,8)
  if uS.loopCleared then
    screen.text("CLR")
  elseif uS.recording==2 then
    screen.text("REC")
  elseif uS.recording==1 then
    screen.level(1)
    screen.text("REC")
    screen.level(15)
  elseif uP[uS.loopNum].isStopped then
    screen.text("||")
  else
    screen.text(">")
  end
  
  -- show loop info
  x=7+shift_amount
  y=9+shift_amount
  screen.move(x,y)
  if uS.loopNum==7 then
    screen.text("A")
  else
    screen.text(uS.loopNum)
  end
  screen.move(x,y)
  screen.rect(x-3,y-7,10,10)
  screen.stroke()
  
  if uS.selectedPar==1 or uS.selectedPar==2 then
    screen.move(x+10,y)
    if uS.selectedPar==1 then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.text(string.format("%1.1f",uP[uS.loopNum].loopStart))
    
    screen.move(x+24,y)
    screen.level(1)
    screen.text("-")
    
    screen.move(x+30,y)
    if uS.selectedPar==2 then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.text(string.format("%1.1fs",uP[uS.loopNum].loopStart+uP[uS.loopNum].loopLength))
  elseif uS.selectedPar==3 then
    screen.move(x+15,y)
    screen.text("level")
  elseif uS.selectedPar==4 then
    screen.move(x+15,y)
    screen.text(string.format("rate %1.2f",uP[uS.loopNum].rate))
  elseif uS.selectedPar==5 then
    screen.move(x+15,y)
    screen.text("pan")
  end
  
  -- screen.move(x+55,y)
  -- if uS.selectedPar==3 then
  --   screen.level(15)
  -- else
  --   screen.level(1)
  -- end
  -- screen.text(string.format("%1.2f",uP[uS.loopNum].vol))
  
  -- screen.move(x+80,y)
  -- if uS.selectedPar==4 then
  --   screen.level(15)
  -- else
  --   screen.level(1)
  -- end
  -- screen.text(string.format("%1.2f",uP[uS.loopNum].rate))
  
  -- screen.move(x+105,y)
  -- if uS.selectedPar==5 then
  --   screen.level(15)
  -- else
  --   screen.level(1)
  -- end
  -- screen.text(string.format("%1.2f",uP[uS.loopNum].pan))
  
  -- draw representation of current loop states
  for i=1,6 do
    -- draw circles
    r=(uC.radiiMinMax[2]-uC.radiiMinMax[1])*uP[i].loopLength/(uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2])+uC.radiiMinMax[1]
    x=uC.centerOffsets[i][1]+(uC.widthMinMax[2]-uC.widthMinMax[1])*(uP[i].pan+1)/2+uC.widthMinMax[1]
    y=uC.centerOffsets[i][2]+(uC.heightMinMax[2]-uC.heightMinMax[1])*(1-uP[i].vol)+uC.heightMinMax[1]
    if uS.loopNum==i then
      screen.line_width(1)
      screen.level(15)
    else
      screen.line_width(1)
      screen.level(1)
    end
    screen.move(x+r,y)
    screen.circle(x,y,r)
    screen.stroke()
    
    angle=360*(uP[i].loopLength-uP[i].position)/(uP[i].loopLength)+90
    
    -- if not uP[i].isStopped then
    --   -- draw arc at position
    --   screen.move(x,y)
    --   screen.arc(x,y,r,math.rad(angle-5),math.rad(angle+5))
    --   screen.stroke()
    -- end
    
    -- draw pixels at position
    for j=-1,1 do
      screen.pixel(x+(r-j)*math.sin(math.rad(angle)),y+(r-j)*math.cos(math.rad(angle)))
      screen.stroke()
    end
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

local clock=os.clock
function sleep(n) -- seconds
  local t0=clock()
  while clock()-t0<=n do end
end
