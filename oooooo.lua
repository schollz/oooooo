-- oooooo v0.1.0
--

-- user parameters
uP={
}

-- user state
uS={
  updateUI=false,
  updateParams=false,
  shift=false,
  loopNum=1,-- 0 = all loops
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
  centerOffsets={
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
  },
}

flag_update_ui=false
flag_update_params=false

function init()
  -- initialize user parameters
  for i=1,6 do
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
  
  -- TODO: load parameters from file?
  
  -- TODO: load buffer from file
  
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
    softcut.level_slew_time(i,0)
    softcut.rate_slew_time(i,0.5)
    
    softcut.rec_level(i,1)
    softcut.pre_level(i,1)
    softcut.position(i,uC.bufferMinMax[i][2])
    softcut.buffer(i,uC.bufferMinMax[i][1])
    softcut.enable(i,1)
  end
  
  -- initialize timer
  timer=metro.init()
  timer.time=0.05
  timer.count=-1
  timer.event=update_timer
  timer:start()
  
  -- position poll
  softcut.phase_quant(1,0.025)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
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

--
-- tape functions
--
function tape_stop_reset(n)
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
  end
  for i=i1,i2 do
    if uP[i].isStopped then
      -- reset to 0 position
      if uP[i].position~=0 then
        -- move to beginning of loop
        uP[i].position=0
        softcut.position(i,uP[i].position+uC.bufferMinMax[i][2]+uP[i].loopStart)
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
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
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
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
  end
  for i=i1,i2 do
    if uP[i].isRecording then
      -- stop recording, if recording
      softcut.rec(i,0)
    end
    
    -- start playing
    softcut.rate(i,uP[i].rate)
    softcut.play(i,1)
    uP[i].isStopped=false
  end
end

function tape_rec(n)
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
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
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
  end
  for i=i1,i2 do
    uP[i].loopStart=lstart
    uP[i].loopLength=llength
    if uP[i].loopLength+uP[i].loopStart>uC.loopMinMax[2] then
      -- loop length is too long, shorten it
      uP[i].loopLength=uC.loopMinMax[2]-uP[i].loopStart
    end
    -- move to start of loop if position is outside of loop
    if uP[i].position<uP[i].loopStart or uP[i].position>uP[i].loopStart+uP[i].loopLength then
      uP[i].position=uP[i].loopStart
      softcut.position(i,uP[i].position+uC.bufferMinMax[i][2])
    end
    sofcut.loop_start(i,uP[i].loopStart+uC.bufferMinMax[i][2])
    sofcut.loop_end(i,uP[i].loopStart+uC.bufferMinMax[i][2]+uP[i].loopLength)
  end
end

--
-- encoders
--
function enc(n,d)
  if n==1 then
    uS.loopNum=util.clamp(uS.loopNum+d,0,6)
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
  
  screen.update()
end
