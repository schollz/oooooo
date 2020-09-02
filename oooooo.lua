-- oooooo v0.4
-- 6 x digital tape loops
--
-- llllllll.co/t/oooooo
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
  recording=0,-- 0 = not recording, 1 = armed, 2 = recording
  recordingTime=0,
  updateUI=false,
  updateParams=0,
  updateTape=false,
  shift=false,
  loopNum=1,-- 7 = all loops
  selectedPar=0,
  flagClearing=false,
  flagSpecial=0,
  message="",
}

-- user constants
uC={
  bufferMinMax={
    {1,1,80},
    {1,82,161},
    {1,163,243},
    {2,1,80},
    {2,82,161},
    {2,163,243},
  },
  loopMinMax={0.2,78},
  radiiMinMax={3,160},
  widthMinMax={8,124},
  heightMinMax={0,64},
  centerOffsets={
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
  },
  updateTimerInterval=0.05,
  recArmThreshold=0.03,
  backupNumber=1,
  lfoTime=1,
}

PATH=_path.audio..'oooooo/'

function init()
  init_loops(7)
  
  -- make data directory
  if not util.file_exists(PATH) then util.make_dir(PATH) end
  
  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=uC.updateTimerInterval
  timer.count=-1
  timer.event=update_timer
  timer:start()
  
  -- position poll
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
  -- listen to audio
  -- and initiate recording on incoming audio
  p_amp_in=poll.set("amp_in_l")
  -- set period low when primed, default 1 second
  p_amp_in.time=1
  p_amp_in.callback=function(val)
    if uS.recording==1 then
      print("incoming signal = "..val)
      if val>params:get("rec thresh")/1000 then
        tape_rec(uS.loopNum)
      end
    end
  end
  p_amp_in:start()
  
  -- add variables into main menu
  params:add_control("rec thresh","rec thresh",controlspec.new(0.001*1000,0.1*1000,'exp',0.001*1000,0.03*1000,'amp/1k'))
  params:set_action("rec thresh",update_parameters)
  params:add_control("backup","backup",controlspec.new(1,8,'lin',1,1))
  params:set_action("backup",update_parameters)
  params:add_control("vol pinch","vol pinch",controlspec.new(0,1000,'lin',1,500,'ms'))
  params:set_action("vol pinch",update_parameters)
  params:add_option("keep rec","keep rec",{"no","yes"},1)
  params:set_action("keep rec",update_parameters)
  params:read("oooooo.pset")
  
  redraw()
end

function init_loops(j)
  audio.level_adc(1) -- input volume 1
  audio.level_adc_cut(1) -- ADC to Softcut input
  audio.level_cut(1) -- Softcut master level (same as in LEVELS screen)
  
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=7
  end
  for i=i1,i2 do
    print("initializing  "..i)
    uP[i]={}
    uP[i].loopStart=0
    uP[i].position=uP[i].loopStart
    uP[i].loopLength=(60/clock.get_tempo())*i*4
    uP[i].recordedLength=0
    uP[i].isStopped=true
    uP[i].isEmpty=true
    uP[i].vol=0.5
    uP[i].rate=1
    uP[i].pan=0
    uP[i].lfoWarble={}
    for j=1,3 do
      uP[i].lfoWarble[j]=math.random(1,60)
    end
    
    if i<7 then
      -- update softcut
      softcut.level(i,0.5)
      softcut.level_input_cut(1,i,1)
      softcut.level_input_cut(2,i,1)
      softcut.pan(i,0)
      softcut.play(i,0)
      softcut.rate(i,1)
      softcut.loop_start(i,uC.bufferMinMax[i][2])
      softcut.loop_end(i,uC.bufferMinMax[i][2]+uP[i].loopLength)
      softcut.loop(i,1)
      softcut.rec(i,0)
      
      softcut.fade_time(i,0.2)
      softcut.level_slew_time(i,0.8)
      softcut.rate_slew_time(i,0.8)
      
      softcut.rec_level(i,1)
      softcut.pre_level(i,1)
      softcut.buffer(i,uC.bufferMinMax[i][1])
      softcut.position(i,uC.bufferMinMax[i][2])
      softcut.enable(i,1)
      softcut.phase_quant(i,0.025)
    end
  end
end

function randomize_parameters()
  random_rates={-4,-2,-1,-0.5,-0.25,0.25,0.5,1,2,4}
  for i=1,6 do
    uP[i].rate=random_rates[math.random(#random_rates)]
    softcut.rate(i,uP[i].rate)
    uP[i].vol=math.random(2,10)/10*(1/math.abs(uP[i].rate))
    uP[i].vol=util.clamp(uP[i].vol,0,1)
    softcut.level(i,uP[i].vol)
    uP[i].pan=math.random(-1,1)*0.75
    softcut.pan(i,uP[i].pan)
  end
end

--
-- updaters
--
function update_parameters(x)
  params:write("oooooo.pset")
end

function update_positions(i,x)
  -- adjust position so it is relative to loop start
  uP[i].position=x-uC.bufferMinMax[i][2]
  uS.updateUI=true
end

function update_timer()
  -- -- update the count for the lfos
  -- uC.lfoTime=uC.lfoTime+uC.updateTimerInterval
  -- if uC.lfoTime>376.99 then -- 60 * 2 * pi
  --   uC.lfoTime=0
  -- end
  -- tape_warble()
  
  if uS.updateUI then
    redraw()
  end
  if uS.recording==2 then
    uS.recordingTime=uS.recordingTime+uC.updateTimerInterval
    if uS.recordingTime>=uP[uS.loopNum].loopLength then
      -- stop recording when reached a full loop
      tape_stop_rec(uS.loopNum,false)
    end
  end
end

--
-- saving and loading
--
function backup_save()
  print("backup_save")
  clock.run(function()
    uS.message="saved"
    redraw()
    clock.sleep(0.5)
    uS.message=""
    redraw()
  end)
  
  -- write file of user data
  file=io.open(PATH.."oooooo"..params:get("backup")..".json","w")
  io.output(file)
  io.write(json.stringify(uP))
  io.close(file)
  
  -- save tape
  softcut.buffer_write_stereo(PATH.."oooooo"..params:get("backup")..".wav",0,-1)
end

function backup_load()
  print("backup_load")
  clock.run(function()
    uS.message="loaded"
    redraw()
    clock.sleep(0.5)
    uS.message=""
    redraw()
  end)
  
  -- -- load parameters from file
  if util.file_exists(PATH.."oooooo"..params:get("backup")..".json") then
    filecontents=readAll(PATH.."oooooo"..params:get("backup")..".json")
    print(filecontents)
    uP=json.parse(filecontents)
  end
  
  -- load buffer from file
  if util.file_exists(PATH.."oooooo"..params:get("backup")..".wav") then
    softcut.buffer_clear()
    softcut.buffer_read_stereo(PATH.."oooooo"..params:get("backup")..".wav",0,0,-1)
  end
end

--
-- tape effects
--
function tape_warble()
  for i=1,6 do
    if uP[i].isStopped or uS.recording>0 then
      -- do nothing
    else
      warblePercent=0
      for j=1,3 do
        warblePercent=warblePercent+math.sin(2*math.pi*uC.lfoTime/uP[i].lfoWarble[j])
      end
      softcut.rate(i,uP[i].rate*(1+warblePercent/200))
    end
  end
end

--
-- tape functions
--
function tape_stop_reset(j)
  -- if uS.loopNum == 7 then stop all
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if uP[i].isStopped and uS.recording==0 then
      tape_reset(i)
    else
      tape_stop(i)
    end
  end
end

function tape_reset(i)
  if uP[i].position==0 then
    do return end
  end
  print("tape_reset "..i)
  uP[i].position=0
  softcut.position(i,uC.bufferMinMax[i][2]+uP[i].loopStart)
end

function tape_stop(i)
  if uP[i].isStopped==true and uS.recording==0 then
    do return end
  end
  print("tape_stop "..i)
  if uS.recording>0 then
    tape_stop_rec(i,true)
  end
  -- ?????
  -- if this runs as softcut.rate(i,0) though, then overdubbing stops working
  softcut.play(i,0)
  uP[i].isStopped=true
end

function tape_stop_rec(i,change_loop)
  if uS.recording==0 then
    do return end
  end
  print("tape_stop_rec "..i)
  p_amp_in.time=1
  still_armed=(uS.recording==1)
  uS.recording=0
  uP[i].recordedLength=uS.recordingTime
  uS.recordingTime=0
  -- slowly stop
  clock.run(function()
    if params:get("vol pinch")>0 then
      for j=1,10 do
        softcut.rec(i,(10-j)*0.1)
        print("sleeping "..params:get("vol pinch")/10/1000)
        clock.sleep(params:get("vol pinch")/10/1000)
      end
    end
    softcut.rec(i,0)
  end)
  
  -- change the loop size if specified
  print('params:get("keep rec") '..params:get("keep rec"))
  if not still_armed then
    if change_loop then
      uP[i].loopLength=uP[i].recordedLength
      tape_change_loop(i)
    elseif params:get("keep rec")==2 then
      -- keep recording onto the next loop
      nextLoop=0
      for j=1,6 do
        if uP[j].isEmpty then
          nextLoop=j
          break
        end
      end
      -- goto the next loop and record
      if nextLoop>0 then
        uS.loopNum=nextLoop
        tape_rec(uS.loopNum)
      end
    end
  end
end

function tape_clear(i)
  if i<7 and uP[i].isEmpty==true then
    do return end
  end
  print("tape_clear "..i)
  -- prevent double clear
  if uS.flagClearing then
    do return end
  end
  -- signal clearing to prevent double clear
  clock.run(function()
    uS.flagClearing=true
    uS.message="clearing"
    redraw()
    clock.sleep(0.5)
    uS.flagClearing=false
    uS.message=""
    redraw()
  end)
  redraw()
  
  if i==7 then
    -- clear everything
    softcut.buffer_clear()
    for j=1,6 do
      uP[j].isEmpty=true
      uP[j].recordedLength=0
      tape_reset(j)
    end
  else
    -- clear a specific section of buffer
    uP[i].isEmpty=true
    uP[i].recordedLength=0
    softcut.buffer_clear_region_channel(
      uC.bufferMinMax[i][1],
      uC.bufferMinMax[i][2],
    uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2])
    tape_reset(i)
  end
  -- reinitialize?
  -- init_loops(i)
end

function tape_play(j)
  print("tape_play "..j)
  if uS.recording>0 then
    tape_stop_rec(j,true)
  end
  if j<7 and uP[j].isStopped==false then
    do return end
  end
  if j<7 and uP[j].isEmpty then
    do return end
  end
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    softcut.play(i,1)
    softcut.level(i,uP[i].vol)
    softcut.rate(i,uP[i].rate)
    uP[i].isStopped=false
  end
end

function tape_arm_rec(i)
  if uS.recording==1 then
    do return end
  end
  print("tape_arm_rec "..i)
  -- arm  recording
  uS.recording=1
  -- monitor input
  p_amp_in.time=0.025
end

function tape_rec(i)
  if uS.recording==2 then
    do return end
  end
  print("tape_rec "..i)
  if uP[i].isStopped then
    softcut.play(i,1)
    print("setting rate to "..uP[i].rate)
    softcut.rate(i,uP[i].rate)
    softcut.level(i,uP[i].vol)
    uP[i].isStopped=false
  end
  p_amp_in.time=1
  uS.recordingTime=0
  uS.recording=2 -- recording is live
  softcut.rec_level(i,1)
  softcut.pre_level(i,1)
  uP[i].isEmpty=false
  redraw()
  -- slowly start recording
  -- ease in recording signal to avoid clicks near loop points
  clock.run(function()
    if params:get("vol pinch")>0 then
      for j=1,10 do
        softcut.rec(i,j*0.1)
        clock.sleep(params:get("vol pinch")/10/1000)
      end
    end
    softcut.rec(i,1)
  end)
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
    d=sign(d)
    uS.loopNum=util.clamp(uS.loopNum+d,1,7)
  elseif n==2 then
    d=sign(d)
    if uS.loopNum~=7 then
      uS.selectedPar=util.clamp(uS.selectedPar+d,0,5)
    else
      -- toggle between saving / loading
      uS.flagSpecial=util.clamp(uS.flagSpecial+d,0,3)
    end
  elseif n==3 then
    if uS.loopNum~=7 then
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
    else
      if uS.flagSpecial==1 or uS.flagSpecial==2 then
        -- update tape number
        d=sign(d)
        params:set("backup",util.clamp(params:get("backup")+d,1,8))
      end
    end
  end
  uS.updateUI=true
end

function key(n,z)
  if n==1 then
    uS.shift=not uS.shift
  elseif n==2 and z==1 then
    -- this key works on one or all
    if uS.shift then
      -- clear
      tape_clear(uS.loopNum)
    else
      -- stop tape
      -- if stopped, then reset to 0
      tape_stop_reset(uS.loopNum)
    end
  elseif n==3 and z==1 then
    if uS.shift then
      if uS.loopNum~=7 then
        if uS.recording==0 then
          tape_arm_rec(uS.loopNum)
        elseif uS.recording==1 then
          tape_rec(uS.loopNum)
        end
      else
        -- save/load functionality
        if uS.flagSpecial==1 then
          -- save
          backup_save()
        elseif uS.flagSpecial==2 then
          -- load
          backup_load()
        elseif uS.flagSpecial==3 then
          -- randomize!
          randomize_parameters()
        end
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
  
  -- show state symbol
  if uS.recording==2 then
    screen.rect(108,1,20,10)
    screen.move(111,8)
    screen.text("REC")
  elseif uS.recording==1 then
    screen.rect(108,1,20,10)
    screen.level(1)
    screen.move(111,8)
    screen.text("REC")
    screen.level(15)
  elseif uP[uS.loopNum].isStopped then
    screen.rect(118,1,10,10)
    screen.move(121,8)
    screen.text("||")
  else
    screen.rect(118,1,10,10)
    screen.move(121,8)
    screen.text(">")
    screen.move(122,4)
    screen.line(122,8)
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
  
  x=-7
  y=60
  if uS.loopNum==7 then
    screen.move(x+10,y)
    if uS.flagSpecial==1 then
      screen.text("save "..params:get("backup"))
    elseif uS.flagSpecial==2 then
      screen.text("load "..params:get("backup"))
    elseif uS.flagSpecial==3 then
      screen.text("rand")
    end
  elseif uS.selectedPar==1 or uS.selectedPar==2 then
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
    screen.move(x+10,y)
    screen.text("level")
  elseif uS.selectedPar==4 then
    screen.move(x+10,y)
    screen.text(string.format("rate %1.1f%%",uP[uS.loopNum].rate*100))
  elseif uS.selectedPar==5 then
    screen.move(x+10,y)
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
    if r>45 then
      r=45
    end
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
    
    -- draw pixels at position if it has data or
    -- its being recorded/primed
    if uP[i].isEmpty==false or (i==uS.loopNum and uS.recording>0) then
      for j=-1,1 do
        screen.pixel(x+(r-j)*math.sin(math.rad(angle)),y+(r-j)*math.cos(math.rad(angle)))
        screen.stroke()
      end
    end
  end
  
  if uS.message~="" then
    show_message(uS.message)
  end
  
  screen.update()
end

--
-- utils
--
function show_message(message)
  screen.level(0)
  x=34
  y=28
  w=string.len(message)*8
  screen.rect(x,y,w,10)
  screen.fill()
  screen.level(15)
  screen.rect(x,y,w,10)
  screen.stroke()
  screen.move(x+w/2,y+7)
  screen.text_center(message)
end

function readAll(file)
  local f=assert(io.open(file,"rb"))
  local content=f:read("*all")
  f:close()
  return content
end

function calculate_lfo(current_time,period,offset)
  if period==0 then
    return 1
  else
    return math.sin(2*math.pi*current_time/period+offset)
  end
end

function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function sign(x)
  if x>0 then
    return 1
  elseif x<0 then
    return-1
  else
    return 0
  end
end
