-- oooooo v1.2.0
-- 6 x digital tape loops
--
-- llllllll.co/t/oooooo
--
--
--
--    ▼ instructions below ▼
--
-- E1 selects loops
-- E2 changes mode/parameter
--
-- in tape mode:
-- K2 stops
-- K2 again resets
-- K3 plays
-- K1+K2 clears
-- K1+K2 again resets
-- K1+K3 primes recording
-- K1+K3 again records
--
-- in other modes:
-- K2 or K3 activates or lfos
-- E3 adjusts parameter

local Formatters=require 'formatters'

local json = nil  
local share = nil 
if util.file_exists("/home/we/dust/code/share.norns.online") then
  json=include("share.norns.online/lib/json")
  share=include("share.norns.online/lib/share")
end

-- user parameters
uP={
  -- initialized in init
}

-- user state
uS={
  recording={0,0,0,0,0,0},-- 0 = not recording, 1 = armed, 2 = recording
  recordingTime={0,0,0,0,0,0},
  recordingLoopNum={0,0,0,0,0,0},
  updateUI=false,
  updateParams=0,
  updateUserParam=0,
  updateTape=false,
  shift=false,
  loopNum=1,-- 7 = all loops
  selectedPar=0,
  flagClearing=false,
  flagSpecial=0,
  message="",
  currentBeat=0,
  currentTime=0,
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
  discreteRates={-400,-200*1.498,-200,-100*1.498,-100,-50*1.498,-50,-25*1.498,-25,0,25,1.498*25,50,1.498*50,100,1.498*100,200,1.498*200,400},
  discreteBeats={1/4,1/2,1,2},
}

PATH=_path.audio..'oooooo/'

function init()
  -----------------------
  -- start for sharing --
  -----------------------
  local curtime = os.clock()
  print(curtime)
  params:add_group("SHARING",4)
  local f=io.popen('cd /home/we/dust/data/oooooo; ls -d *')
  shareable = {"-"}
  for name in f:lines() do
    if string.match(name,".json") and string.match(name,"20") then
      table.insert(shareable,name:match("^(.+).json$"))
    end
  end
  params:add {
    type='option',
    id='choose_shared',
    name='CHOOSE',
    options=shareable,
    action=function(value)
      print(value)
  end}
  params:add{ type='binary', name="LOAD", id='load_shared', behavior='momentary', 
      action=function(v) 
        choose_shared = params:get("choose_shared")
        if v==1 and choose_shared > 1 then
        print("LOADING") 
        _menu.redraw()
        params:set("show_msg","LOADING")
          datename = "/home/we/dust/data/oooooo/"..shareable[choose_shared]
          -- update state
          data = json.decode(share.read_file(datename..".json"))
          if data ~= nil then 
            state = data
          end
          -- update softcut
          softcut.buffer_read_stereo(datename..".wav",0,0,-1)
          -- update parameters
          curtime=os.clock() -- prevent bang
          params:read(datename..".pset")
          params:set("choose_shared",choose_shared)
          params:set("show_msg","LOADED")
          _menu.redraw()
          tape_play(7)
        end
  end}
  params:add{ type='binary', name="UPLOAD", id='upload_share', behavior='momentary', 
    action=function(v) 
      print(os.clock()-curtime)
      if v == 1 and os.clock()-curtime > 0.02 then
        print("UPLOADING") 
        params:set("show_msg","UPLOADING")
        _menu.redraw()
        -- generate a date-based name
        datename = os.date("%Y%m%d%H%M")
        -- encode state and upload
        statejson = json.encode(uS)
        share.write_file("/dev/shm/"..datename..".json",statejson)
        share.upload("oooooo",datename,"/dev/shm/"..datename..".json","/home/we/dust/data/oooooo/")
        os.remove("/dev/shm/"..datename..".json")
        -- encode parameters and upload
        params:write("/dev/shm/"..datename..".pset")
        share.upload("oooooo",datename,"/dev/shm/"..datename..".pset","/home/we/dust/data/oooooo/")
        os.remove("/dev/shm/"..datename..".json")
        -- dump softcut and upload
        softcut.buffer_write_stereo("/dev/shm/"..datename..".wav",0,-1)
        share.upload("oooooo",datename,"/dev/shm/"..datename..".wav","/home/we/dust/data/oooooo/")
        os.remove("/dev/shm/"..datename..".wav")        
        params:set("show_msg","UPLOADED")
      end
  end}
  params:add_text('show_msg',"MESSAGE","")

  --------------------------
  -- end of sharing stuff -- 
  --------------------------
  params:add_separator("oooooo")
  -- add variables into main menu

  params:add_group("startup",4)
  params:add_option("load on start","load on start",{"no","yes"},1)
  params:set_action("load on start",update_parameters)
  params:add_option("play on start","play on start",{"no","yes"},1)
  params:set_action("play on start",update_parameters)
  params:add_option("start lfos random","start lfos random",{"no","yes"},1)
  params:set_action("start lfos random",update_parameters)
  params:add_control("start length","start length",controlspec.new(0,64,'lin',1,0,'beats'))
  params:set_action("start length",update_parameters)

  params:add_group("recording",7)
  params:add_control("pre level","pre level",controlspec.new(0,1,"lin",0.01,1,"",0.01))
  params:set_action("pre level",update_parameters)
  params:add_control("rec level","rec level",controlspec.new(0,1,"lin",0.01,1,"",0.01))
  params:set_action("rec level",update_parameters)
  params:add_control("rec thresh","rec thresh",controlspec.new(1,100,'exp',1,10,'amp/1k'))
  params:set_action("rec thresh",update_parameters)
  params:add_control("vol pinch","vol pinch",controlspec.new(0,1000,'lin',1,500,'ms'))
  params:set_action("vol pinch",update_parameters)
  params:add_option("rec thru loops","rec thru loops",{"no","yes"},1)
  params:set_action("rec thru loops",update_parameters)
  params:add_control("stop rec after","stop rec after",controlspec.new(1,64,"lin",1,1,"loops"))
  params:set_action("stop rec after",update_parameters)
  params:add_option("input type","input type",{"line-in","tape","line-in+tape"},3)
  params:set_action("input type",function(x)
    update_softcut_input()
    update_parameters()
  end)

  params:add_group("other",4)
  params:add_control("backup","tape (backup/save)",controlspec.new(1,8,'lin',1,1))
  params:set_action("backup",update_parameters)
  params:add_option("continous rate","continous rate",{"no","yes"},2)
  params:set_action("continous rate",update_parameters)
  params:add_control("slew rate","slew rate",controlspec.new(0,30,'lin',0.1,(60/clock.get_tempo())*4,"s",0.1/30))
  params:set_action("slew rate",function(x)
    for i=1,6 do
      softcut.level_slew_time(i,x)
      softcut.rate_slew_time(i,x)
    end
  end)
  params:add_option("expert mode","expert mode",{"no","yes"},1)
  params:set_action("expert mode",update_parameters)

  params:add_group("all loops",5)
  params:add_option("pause lfos","pause lfos",{"no","yes"},1)
  params:add_control("destroy loops","destroy loops",controlspec.new(0,100,'lin',1,0,'% prob'))
  params:add_control("vol ramp","vol ramp",controlspec.new(-1,1,'lin',0,0,'',0.01/2))
  params:add_option("randomize all on reset","randomize on reset",{"no","params","loops","both"},1)
  params:set_action("randomize all on reset",function(x)
    for i=1,6 do
      params:set(i.."randomize on reset",x)
    end
  end)
  params:add_control("reset all every","reset all every",controlspec.new(0,64,"lin",1,0,"beats"))
  params:set_action("reset all every",function(x)
    for i=1,6 do
      params:set(i.."reset every beat",x)
    end
  end)

  -- TODO: hook up pausing lfos
  params:read(_path.data..'oooooo/'.."oooooo.pset")

  -- reset defaults
  params:set("slew rate",(60/clock.get_tempo())*4)

  -- add parameters
  filter_resonance = controlspec.new(0.05,1,'lin',0,0.25,'')
  filter_freq = controlspec.new(20,20000,'exp',0,20000,'Hz')
  for i=1,6 do
    params:add_group("loop "..i,30)
    --                 id      name min max default k units
    params:add_control(i.."start","start",controlspec.new(0,uC.loopMinMax[2],"lin",0.01,0,"s",0.01/uC.loopMinMax[2]))
    params:add_control(i.."start lfo amp","start lfo amp",controlspec.new(0,1,"lin",0.01,0.2,"",0.01))
    params:add_control(i.."start lfo period","start lfo period",controlspec.new(0,60,"lin",0.1,0,"s",0.1/60))
    params:add_control(i.."start lfo offset","start lfo offset",controlspec.new(0,60,"lin",0.1,0,"s",0.1/60))
    params:add_control(i.."length","length",controlspec.new(uC.loopMinMax[1],uC.loopMinMax[2],"lin",0.01,(60/clock.get_tempo())*i*4,"s",0.01/uC.loopMinMax[2]))
    params:add_control(i.."length lfo amp","length lfo amp",controlspec.new(0,1,"lin",0.01,0.2,"",0.01))
    params:add_control(i.."length lfo period","length lfo period",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."length lfo offset","length lfo offset",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."vol","vol",controlspec.new(0,1,"lin",0.01,0.1,"",0.01))
    params:add_control(i.."vol lfo amp","vol lfo amp",controlspec.new(0,1,"lin",0.01,0.25,"",0.01))
    params:add_control(i.."vol lfo period","vol lfo period",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."vol lfo offset","vol lfo offset",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_option(i.."rate","rate (%)",uC.discreteRates,#uC.discreteRates)
    params:add_control(i.."rate adjust","rate adjust (%)",controlspec.new(-400,400,"lin",0.1,0,"%",0.1/800))
    params:add_option(i.."rate reverse","reverse rate",{"on","off"},2)
    params:add_option(i.."rate lfo center","rate lfo center (%)",uC.discreteRates,#uC.discreteRates)
    params:add_control(i.."rate lfo amp","rate lfo amp",controlspec.new(0,1,"lin",0.01,0.25,"",0.01))
    params:add_control(i.."rate lfo period","rate lfo period",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."rate lfo offset","rate lfo offset",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."pan","pan",controlspec.new(-1,1,"lin",0.01,0,"",0.01/2))
    params:add_control(i.."pan lfo amp","pan lfo amp",controlspec.new(0,1,"lin",0.01,0.2,"",0.01))
    params:add_control(i.."pan lfo period","pan lfo period",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."pan lfo offset","pan lfo offset",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."reset every beat","reset every",controlspec.new(0,64,"lin",1,0,"beats"))
    params:add_option(i.."randomize on reset","randomize on reset",{"no","params","loops","both"},1)
    params:add {
      type='control',
      id=i..'filter_frequency',
      name='filter cutoff',
      controlspec=filter_freq,
      formatter=Formatters.format_freq,
      action=function(value)
          softcut.post_filter_fc(i,value)
      end
    }
    params:add {
      type='control',
      id=i..'filter_reso',
      name='filter resonance',
      controlspec=filter_resonance,
      action=function(value)
        softcut.post_filter_rq(i,value)
      end
    }
    params:add{ type='binary', name="recording trig", id=i..'recording trig', behavior='momentary', 
      action=function(v) 
        if v == 1 then 
          if uS.recording[i]>0 then
            tape_stop_rec(i)
          else
            tape_rec(i)
          end
        end
    end }
    params:add{ type='binary', name="arming trig", id=i..'arming trig', behavior='momentary', 
      action=function(v) 
        if v == 1 then 
          if uS.recording[i]>0 then
            tape_stop_rec(i)
          else
            tape_arm_rec(i)
          end
        end
    end }
    params:add_option(i.."isempty","is empty",{"false","true"},2)
  end

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
    for i=1,6 do
      if uS.recording[i]==1 then
        -- print("incoming signal = "..val)
        if val>params:get("rec thresh")/1000 then
          tape_rec(i)
        end
      end
    end
  end
  p_amp_in:start()

  for i=1,6 do
    params:set_action(i.."vol",function(x) uP[i].volUpdate=true end)
    params:set_action(i.."length",function(x) uP[i].loopUpdate=true end)
    params:set_action(i.."start",function(x) uP[i].loopUpdate=true end)
    params:set_action(i.."pan",function(x) uP[i].panUpdate=true end)
    params:set_action(i.."rate",function(x) uP[i].rateUpdate=true end)
    params:set_action(i.."rate reverse",function(x) uP[i].rateUpdate=true end)
    params:set_action(i.."rate adjust",function(x) uP[i].rateUpdate=true end)
  end
  redraw()

  if params:get("start lfos random")==2 then
    randomize_lfos()
  end

  -- end of init
  if params:get("load on start")==2 then
    backup_load()
    if params:get("play on start")==2 then
      tape_play(7)
    end
  else
    tape_stop(1)
    tape_reset(1)
  end

  update_softcut_input()
end

function init_loops(j)
  audio.level_adc(1) -- input volume 1
  audio.level_cut(1) -- Softcut master level (same as in LEVELS screen)

  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=7
  end
  for i=i1,i2 do
    print("initializing  "..i)
    -- TODO: if using save file, then load the last save
    uP[i]={}
    uP[i].loopStart=0
    uP[i].loopLength=(60/clock.get_tempo())*i*4
    if params:get("start length")>0 then
      uP[i].loopLength=(60/clock.get_tempo())*params:get("start length")
    end
    uP[i].loopUpdate=false
    uP[i].position=uP[i].loopStart
    uP[i].recordedLength=0
    uP[i].isStopped=true
    uP[i].vol=0.5
    uP[i].volUpdate=false
    uP[i].rate=1
    uP[i].rateUpdate=false
    uP[i].pan=0
    uP[i].panUpdate=false
    uP[i].lfoWarble={}
    uP[i].destroying=false
    if i<7 then
      params:set(i.."start",0)
      params:set(i.."start lfo amp",0.2)
      params:set(i.."start lfo period",0)
      params:set(i.."start lfo offset",0)
      params:set(i.."length",uP[i].loopLength)
      params:set(i.."length lfo amp",0.2)
      params:set(i.."length lfo period",0)
      params:set(i.."length lfo offset",0)
      params:set(i.."vol",0.5)
      params:set(i.."vol lfo amp",0.3)
      params:set(i.."vol lfo period",0)
      params:set(i.."vol lfo offset",0)
      params:set(i.."rate",15)
      params:set(i.."rate adjust",0)
      params:set(i.."rate reverse",2)
      params:set(i.."rate lfo center",10)
      params:set(i.."rate lfo amp",0.2)
      params:set(i.."rate lfo period",0)
      params:set(i.."rate lfo offset",0)
      params:set(i.."pan",0)
      params:set(i.."pan lfo amp",0.5)
      params:set(i.."pan lfo period",0)
      params:set(i.."pan lfo offset",0)
      params:set(i.."reset every beat",0)
      params:set(i.."isempty",2)
    end
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
      softcut.level_slew_time(i,params:get("slew rate"))
      softcut.rate_slew_time(i,params:get("slew rate"))

      softcut.rec_level(i,params:get("rec level"))
      softcut.pre_level(i,params:get("pre level"))
      softcut.buffer(i,uC.bufferMinMax[i][1])
      softcut.position(i,uC.bufferMinMax[i][2])
      softcut.enable(i,1)
      softcut.phase_quant(i,0.025)

      softcut.post_filter_dry(i,0.0)
      softcut.post_filter_lp(i,1.0)
      softcut.post_filter_rq(i,0.3)
      softcut.post_filter_fc(i,44100)

      softcut.pre_filter_dry(i,1.0)
      softcut.pre_filter_lp(i,1.0)
      softcut.pre_filter_rq(i,0.3)
      softcut.pre_filter_fc(i,44100)
    end
  end
end

function randomize_parameters(j)
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    params:set(i.."rate adjust",0)
    -- randomize rates between 25%, 50%, 100%, 200%, 400%
    -- params:set(i.."rate",math.random(#uC.discreteRates))

    -- randomize rates between 25%, 50%, 100%
    params:set(i.."rate",math.random(3)+5)
    params:set(i.."rate reverse",math.floor(math.random()*2)+1)
    uP[i].rateUpdate=true
    params:set(i.."vol",math.random()*0.6+0.2)
    uP[i].volUpdate=true
    params:set(i.."pan",math.random()*2-1)
    uP[i].panUpdate=true
  end
end

function randomize_loops(j)
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    params:set(i.."length",util.clamp(params:get(i.."length")+math.random()*2-1,uC.loopMinMax[1],uC.loopMinMax[2]))
    uP[i].loopUpdate=true
  end
end

function randomize_lfos()
  for i=1,6 do
    -- params:set(i.."length lfo period",math.random()*30+5)
    -- params:set(i.."length lfo offset",math.random()*60)
    params:set(i.."vol lfo period",round_time_to_nearest_beat(math.random()*20+2))
    params:set(i.."vol lfo offset",round_time_to_nearest_beat(math.random()*60))
    params:set(i.."vol lfo amp",math.random()*0.25+0.1)
    params:set(i.."pan lfo amp",math.random()*0.6+0.2)
    params:set(i.."pan lfo period",round_time_to_nearest_beat(math.random()*20+2))
    params:set(i.."pan lfo offset",round_time_to_nearest_beat(math.random()*60))
  end
end

--
-- updaters
--
function update_softcut_input()
  if params:get("input type")==1 then
    print("adc only")
    audio.level_adc_cut(1)
    audio.level_tape_cut(0)
  elseif params:get("input type")==2 then
    print("tape only")
    audio.level_tape_cut(1)
    audio.level_adc_cut(0)
  else
    print("tape+adc only")
    audio.level_adc_cut(1)
    audio.level_tape_cut(1)
  end
end

function update_parameters(x)
  params:write(_path.data..'oooooo/'.."oooooo.pset")
end

function update_positions(i,x)
  -- adjust position so it is relative to loop start
  uP[i].position=x-uC.bufferMinMax[i][2]
  uS.updateUI=true
end

function update_timer()
  if params:get("pause lfos")==1 then
    uS.currentTime=uS.currentTime+uC.updateTimerInterval
  end
  -- -- update the count for the lfos
  -- uC.lfoTime=uC.lfoTime+uC.updateTimerInterval
  -- if uC.lfoTime>376.99 then -- 60 * 2 * pi
  --   uC.lfoTime=0
  -- end
  -- tape_warble()

  if uS.updateUI then
    redraw()
  end
  for i=1,6 do
    if uS.recording[i]==2 then
      uS.recordingTime[i]=uS.recordingTime[i]+uC.updateTimerInterval
      if uS.recordingTime[i]>=uP[i].loopLength then
        uS.recordingLoopNum[i]=uS.recordingLoopNum[i]+1
        if uS.recordingLoopNum[i]>=params:get("stop rec after") and uS.recordingLoopNum[i]<64 then
          -- stop recording when reached a full loop
          tape_stop_rec(i,false)
        end
      end
    end
  end
  if math.floor(clock.get_beats())~=uS.currentBeat then
    -- a beat has been hit
    if params:get("vol ramp")~=0 then
      for i=1,6 do
        params:set(i.."vol",util.clamp(params:get(i.."vol")+params:get("vol ramp")/10,0,1))
      end
    end
    if params:get("destroy loops")>0 and math.random()*100<params:get("destroy loops") then
      -- cause destruction to moving non empty loops
      nonEmptyLoops={}
      for i=1,6 do
        if params:get(i.."isempty")==1 and uP[i].isStopped==false and uP[i].destroying==false then
          table.insert(nonEmptyLoops,i)
        end
      end
      if #nonEmptyLoops>0 then
        -- select a loop at random
        loopDestroy=nonEmptyLoops[math.random(#nonEmptyLoops)]
        clock.run(function()
          numBeats=uC.discreteBeats[math.random(#uC.discreteBeats)]
          preLevel=math.random()
          print("destroying "..loopDestroy.." for "..numBeats.." at "..preLevel.." pre level")
          uP[loopDestroy].destroying=true
          softcut.rec_level(loopDestroy,0)
          softcut.pre_level(loopDestroy,preLevel)
          softcut.rec(loopDestroy,1)
          clock.sync(numBeats)
          softcut.rec_level(loopDestroy,1)
          softcut.pre_level(loopDestroy,1)
          softcut.rec(loopDestroy,0)
          uP[loopDestroy].destroying=false
        end)
      end
    end
    uS.currentBeat=math.floor(clock.get_beats())
    for i=1,6 do
      if params:get(i.."reset every beat")>0 then
        if uS.currentBeat%params:get(i.."reset every beat")==0 then
          tape_reset(i)
        end
      end
    end
  end
  for i=1,6 do
    if uP[i].volUpdate or (params:get(i.."vol lfo period")>0 and params:get("pause lfos")==1 and params:get(i.."vol lfo amp")>0) then
      uS.updateUI=true
      uP[i].volUpdate=false
      uP[i].vol=params:get(i.."vol")
      if params:get(i.."vol lfo period")>0 and params:get("pause lfos")==1 then
        uP[i].vol=uP[i].vol+params:get(i.."vol lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."vol lfo period"),params:get(i.."vol lfo offset"))
        uP[i].vol=util.clamp(uP[i].vol,0,1)
      end
      softcut.level(i,uP[i].vol)
    end
    if uP[i].rateUpdate  or (params:get(i.."rate lfo period")>0 and params:get("pause lfos")==1 and params:get(i.."rate lfo amp")>0) or
      uP[i].rate ~= uC.discreteRates[params:get(i.."rate")]+params:get(i.."rate adjust") then
      uS.updateUI=true
      uP[i].rateUpdate=false
      local currentRateIndex = params:get(i.."rate")
      if params:get(i.."rate lfo period")>0 and params:get(i.."rate lfo amp")>0 and params:get("pause lfos")==1 then
        currentRateIndex=util.clamp(params:get(i.."rate lfo center")+round(util.linlin(-1,1,-#uC.discreteRates,#uC.discreteRates,params:get(i.."rate lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."rate lfo period"),params:get(i.."rate lfo offset")))),1,#uC.discreteRates)
        -- currentRateIndex=util.clamp(round(util.linlin(-1,1,0,1+#uC.discreteRates,params:get(i.."rate lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."rate lfo period"),params:get(i.."rate lfo offset")))),1,#uC.discreteRates)
      end
      uP[i].rate=uC.discreteRates[currentRateIndex]+params:get(i.."rate adjust")
      uP[i].rate=uP[i].rate*(params:get(i.."rate reverse")*2-3)/100.0
      softcut.rate(i,uP[i].rate)
    end
    if uP[i].panUpdate or (params:get(i.."pan lfo period")>0 and params:get("pause lfos")==1 and params:get(i.."pan lfo amp")>0) then
      uS.updateUI=true
      uP[i].panUpdate=false
      uP[i].pan=params:get(i.."pan")
      if params:get(i.."pan lfo period")>0 and params:get("pause lfos")==1 then
        uP[i].pan=uP[i].pan+params:get(i.."pan lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."pan lfo period"),params:get(i.."pan lfo offset"))
      end
      uP[i].pan=util.clamp(uP[i].pan,-1,1)
      softcut.pan(i,uP[i].pan)
    end
    if uP[i].loopUpdate or (params:get(i.."length lfo period")>0 and params:get("pause lfos")==1 and params:get(i.."length lfo amp")>0) or
      (params:get(i.."start lfo period")>0 and params:get("pause lfos")==1 and params:get(i.."start lfo amp")>0) then
      uS.updateUI=true
      uP[i].loopUpdate=false
      uP[i].loopStart=params:get(i.."start")
      if params:get(i.."start lfo period")>0 and params:get("pause lfos")==1 then
        uP[i].loopStart=params:get(i.."start")+uP[i].loopLength*params:get(i.."start lfo amp")*((1+calculate_lfo(uS.currentTime,params:get(i.."start lfo period"),params:get(i.."start lfo offset")))/2)
        uP[i].loopStart=util.clamp(uP[i].loopStart,params:get(i.."start"),uP[i].loopLength+params:get(i.."start"))
      end
      uP[i].loopLength=params:get(i.."length")
      if params:get(i.."length lfo period")>0 and params:get("pause lfos")==1 then
        uP[i].loopLength=uP[i].loopLength*(1+params:get(i.."length lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."length lfo period"),params:get(i.."length lfo offset")))/2
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
      softcut.loop_start(i,uP[i].loopStart+uC.bufferMinMax[i][2])
      softcut.loop_end(i,uP[i].loopStart+uC.bufferMinMax[i][2]+uP[i].loopLength)
    end
  end
end

--
-- saving and loading
--
function backup_save()
  print("backup_save")
  show_message("saved")

  -- write file of user data
  params:write(_path.data..'oooooo/'.."oooooo"..params:get("backup")..".pset")

  -- save tape
  softcut.buffer_write_stereo(PATH.."oooooo"..params:get("backup")..".wav",0,-1)
end

function backup_load()
  print("backup_load")
  show_message("loaded")

  -- load parameters from file
  params:read(_path.data..'oooooo/'.."oooooo"..params:get("backup")..".pset")

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
    if uP[i].isStopped then
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
    if uP[i].isStopped and uS.recording[i]==0 then
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
  if params:get(i.."randomize on reset")>1 then
    if params:get(i.."randomize on reset")==2 then
      randomize_parameters(i)
    elseif params:get(i.."randomize on reset")==3 then
      randomize_loops(i)
    elseif params:get(i.."randomize on reset")==4then
      randomize_parameters(i)
      randomize_loops(i)
    end
  end
end

function tape_stop(i)
  if uP[i].isStopped==true and uS.recording[i]==0 then
    do return end
  end
  print("tape_stop "..i)
  if uS.recording[i]>0 then
    tape_stop_rec(i,true)
  end
  -- ?????
  -- if this runs as softcut.rate(i,0) though, then overdubbing stops working
  softcut.play(i,0)
  uP[i].isStopped=true
end

function tape_stop_rec(i,change_loop)
  if uS.recording[i]==0 then
    do return end
  end
  print("tape_stop_rec "..i)
  p_amp_in.time=1
  still_armed=(uS.recording[i]==1)
  uS.recording[i]=0
  uS.recordingLoopNum[i]=0
  if uS.recordingTime[i]<params:get(i.."length") then
    uP[i].recordedLength=uS.recordingTime[i]
  else
    uP[i].recordedLength=params:get(i.."length")
  end
  uS.recordingTime[i]=0
  -- slowly stop
  clock.run(function()
    if params:get("vol pinch")>0 then
      for j=1,10 do
        softcut.rec(i,(10-j)*0.1)
        clock.sleep(params:get("vol pinch")/10/1000)
      end
    end
    softcut.rec(i,0)
  end)

  -- change the loop size if specified
  print('params:get("rec thru loops") '..params:get("rec thru loops"))
  if not still_armed then
    if change_loop then
      params:set(i.."length",uP[i].recordedLength)
      uP[i].updateLoop=true
    elseif params:get("rec thru loops")==2 then
      -- keep recording onto the next loop
      nextLoop=0
      for j=1,6 do
        if params:get(j.."isempty")==2 then
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
      if params:get(j.."isempty")==2 then
        init_loops(j)
        uS.message="resetting"
        redraw()
      end
      params:set(j.."isempty",2)
      uP[j].recordedLength=0
      tape_stop(j)
      tape_reset(j)
    end
  else
    -- clear a specific section of buffer
    if params:get(i.."isempty")==2 then
      init_loops(i)
      uS.message="resetting"
      redraw()
    end
    params:set(i.."isempty",2)
    uP[i].recordedLength=0
    softcut.buffer_clear_region_channel(
      uC.bufferMinMax[i][1],
      uC.bufferMinMax[i][2],
    uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2])
    tape_stop(i)
    tape_reset(i)
  end
  -- reinitialize?
  -- init_loops(i)
end

function tape_play(j)
  print("tape_play "..j)
  if j<7 and uP[j].isStopped==false and uS.recording[j]==0 then
    do return end
  end
  if j<7 and params:get(j.."isempty")==2 then
    do return end
  end
  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=6
  end
  for i=i1,i2 do
    if uS.recording[i]>0 then
      tape_stop_rec(i,true)
    end
    softcut.play(i,1)
    uP[i].rateUpdate=true
    uP[i].volUpdate=true
    uP[i].isStopped=false
  end
end

function tape_arm_rec(i)
  if uS.recording[i]==1 then
    do return end
  end
  print("tape_arm_rec "..i)
  -- arm  recording
  uS.recording[i]=1
  uS.recordingLoopNum[i]=0
  -- monitor input
  p_amp_in.time=0.025
end

function tape_rec(i)
  if uS.recording[i]==2 then
    do return end
  end
  print("tape_rec "..i)
  if uP[i].isStopped then
    softcut.play(i,1)
    -- print("setting rate to "..uP[i].rate)
    softcut.rate(i,uP[i].rate)
    uP[i].volUpdate=true
    uP[i].isStopped=false
  end
  p_amp_in.time=1
  uS.recordingTime[i]=0
  uS.recording[i]=2 -- recording is live
  softcut.rec_level(i,params:get("rec level"))
  softcut.pre_level(i,params:get("pre level"))
  params:set(i.."isempty",1)
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

--
-- encoders
--
function enc(n,d)
  if n==1 then
    d=sign(d)
    uS.loopNum=util.clamp(uS.loopNum+d,1,7)
  elseif n==2 then
    d=sign(d)
    if uS.loopNum~=7 then
      -- toggle between loop parameters
      uS.selectedPar=util.clamp(uS.selectedPar+d,0,7)
    else
      -- toggle between special parameters
      uS.flagSpecial=util.clamp(uS.flagSpecial+d,0,6)
    end
  elseif n==3 then
    if uS.loopNum~=7 then
      if uS.selectedPar==1 then
        params:set(uS.loopNum.."start",util.clamp(params:get(uS.loopNum.."start")+d/10,0,uC.loopMinMax[2]))
        uP[uS.loopNum].loopUpdate=true
      elseif uS.selectedPar==2 then
        params:set(uS.loopNum.."length",util.clamp(params:get(uS.loopNum.."length")+d/10,uC.loopMinMax[1],uC.loopMinMax[2]))
        uP[uS.loopNum].loopUpdate=true
      elseif uS.selectedPar==3 then
        -- uP[uS.loopNum].vol=util.clamp(uP[uS.loopNum].vol+d/100,0,1)
        params:set(uS.loopNum.."vol",util.clamp(params:get(uS.loopNum.."vol")+d/100,0,1))
        uP[uS.loopNum].volUpdate=true
      elseif uS.selectedPar==4 then
        if params:get("continous rate")==2 then
          params:set(uS.loopNum.."rate adjust",util.clamp(params:get(uS.loopNum.."rate adjust")+d,-400,400))
        else
          d=sign(d)
          params:set(uS.loopNum.."rate adjust",0)
          params:set(uS.loopNum.."rate",util.clamp(params:get(uS.loopNum.."rate")+d,1,#uC.discreteRates))
        end
        uP[uS.loopNum].rateUpdate=true
      elseif uS.selectedPar==5 then
        params:set(uS.loopNum.."pan",util.clamp(params:get(uS.loopNum.."pan")+d/100,-1,1))
        uP[uS.loopNum].panUpdate=true
      elseif uS.selectedPar==6 then
        d=sign(d)
        params:set(uS.loopNum.."reset every beat",util.clamp(params:get(uS.loopNum.."reset every beat")+d,0,64))
      elseif uS.selectedPar==7 then
        -- add temporary warble
        clock.run(function()
          local newChange=(1+d/100)
          uP[uS.loopNum].rate=uP[uS.loopNum].rate*newChange
          softcut.rate(uS.loopNum,uP[uS.loopNum].rate)
          clock.sync(1)
          uP[uS.loopNum].rate=uP[uS.loopNum].rate/newChange
          softcut.rate(uS.loopNum,uP[uS.loopNum].rate)
        end)
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
  elseif z==0 then
    do return end
  elseif (uS.flagSpecial==0 and uS.loopNum==7) or (uS.selectedPar==0 and uS.loopNum<7) then
    -- shift+K2 clears, shift+K3 records only when on tape
    if uS.shift==false and n==2 then
      -- stop tape
      -- if stopped, then reset to 0
      tape_stop_reset(uS.loopNum)
    elseif uS.shift==false and n==3 then
      -- play tape
      tape_play(uS.loopNum)

    elseif n==2 then
      -- clear
      tape_clear(uS.loopNum)
    elseif n==3 then
      if uS.loopNum==7 then
        -- start recording on all
        for i=1,6 do
          tape_rec(i)
        end
      else
        if uS.recording[uS.loopNum]==0 then
          tape_arm_rec(uS.loopNum)
        elseif uS.recording[uS.loopNum]==1 then
          tape_rec(uS.loopNum)
        end
      end
    end
  elseif uS.flagSpecial>0 and uS.loopNum==7 then
    -- shit+K2 or shift+K3 activates parameters
    if uS.flagSpecial==1 then
      -- save
      backup_save()
    elseif uS.flagSpecial==2 then
      -- load
      backup_load()
    elseif uS.flagSpecial==3 then
      -- pause/start lfos
      if params:get("pause lfos")==1 then
        show_message("pausing lfos")
      else
        show_message("unpausing lfos")
      end
      params:set("pause lfos",3-params:get("pause lfos"))
    elseif uS.flagSpecial==4 then
      -- randomize!
      show_message("randomizing")
      randomize_parameters(7)
    elseif uS.flagSpecial==5 then
      -- randomize loops!
      show_message("randomizing loops")
      randomize_loops(7)
    elseif uS.flagSpecial==6 then
      -- randomize lfos!
      show_message("randomizing lfos")
      randomize_lfos()
    end
  elseif uS.selectedPar>0 and uS.loopNum<7 then
    -- shit+K2 or shift+K3 activates parameters when parameter is selected
    if (uS.selectedPar==1 or uS.selectedPar==2) then
      -- toggle lfo for loops
      if params:get(uS.loopNum.."length lfo period")==0 then
        show_message("loop "..uS.loopNum.." lfo on")
        params:set(uS.loopNum.."length lfo offset",math.random()*60)
        params:set(uS.loopNum.."length lfo period",math.random()*60)
        params:set(uS.loopNum.."start lfo offset",math.random()*60)
        params:set(uS.loopNum.."start lfo period",math.random()*60)
      else
        show_message("loop "..uS.loopNum.." lfo off")
        params:set(uS.loopNum.."length lfo period",0)
        params:set(uS.loopNum.."start lfo period",0)
      end
    elseif uS.selectedPar==3 then
      -- toggle lfo for loops
      if params:get(uS.loopNum.."vol lfo period")==0 and uS.loopNum~=7 then
        show_message("vol "..uS.loopNum.." lfo on")
        params:set(uS.loopNum.."vol lfo offset",math.random()*60)
        params:set(uS.loopNum.."vol lfo period",math.random()*60)
      else
        show_message("vol "..uS.loopNum.." lfo off")
        params:set(uS.loopNum.."vol lfo period",0)
      end
    elseif uS.selectedPar==4 then
      if uS.shift then 
        -- toggle rate lfo 
        if params:get(uS.loopNum.."rate lfo period") == 0 then 
          params:set(uS.loopNum.."rate lfo period",0.4)
        end
        if params:get(uS.loopNum.."rate lfo amp") == 0 then 
          params:set(uS.loopNum.."rate lfo amp",0.6)
        else
          params:set(uS.loopNum.."rate lfo amp",0)
        end
      else
        -- toggle reverse
        params:set(uS.loopNum.."rate reverse",3-params:get(uS.loopNum.."rate reverse"))
      end
    elseif uS.selectedPar==5 then
      -- toggle lfo for pan
      if params:get(uS.loopNum.."pan lfo period")==0 and uS.loopNum~=7 then
        show_message("pan "..uS.loopNum.." lfo on")
        params:set(uS.loopNum.."pan lfo offset",math.random()*60)
        params:set(uS.loopNum.."pan lfo period",math.random()*60)
      else
        show_message("pan "..uS.loopNum.." lfo off")
        params:set(uS.loopNum.."pan lfo period",0)
      end
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
  anyRecording=false
  anyPrimed=false
  for i=1,6 do
    if uS.recording[i]==1 then
      anyPrimed=true
      --    screen.level(1)
      --    screen.move(111,i*8+12)
      --    screen.text(i)
    elseif uS.recording[i]==2 then
      anyRecording=true
      --   screen.level(15)
      --   screen.move(111,i*8+12)
      --   screen.text(i)
    end
  end
  screen.level(15)
  if params:get("expert mode")==1 then
    if anyRecording then
      screen.rect(108,1,20,10)
      screen.move(111,8)
      screen.text("REC")
    elseif anyPrimed then
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
  end

  -- show loop info
  x=4+shift_amount
  y=8+shift_amount
  if params:get("expert mode")==1 then
    screen.move(x,y)
    if uS.loopNum==7 then
      screen.text("A")
    else
      screen.text(uS.loopNum)
    end
    screen.move(x,y)
    screen.rect(x-3,y-7,10,10)
    screen.stroke()
  end

  x=-7
  y=60
  if uS.loopNum==7 then
    screen.move(x+10,y)
    if uS.flagSpecial==0 and params:get("expert mode")==1 then
      screen.move(x+10,y)
      tape_icon(x+10,y)
    elseif uS.flagSpecial==1 then
      screen.text("save "..params:get("backup"))
    elseif uS.flagSpecial==2 then
      screen.text("load "..params:get("backup"))
    elseif uS.flagSpecial==3 then
      if params:get("pause lfos")==1 then
        screen.text("pause lfos")
      else
        screen.text("unpause lfos")
      end
    elseif uS.flagSpecial==4 then
      screen.text("rand pars")
    elseif uS.flagSpecial==5 then
      screen.text("rand loop")
    elseif uS.flagSpecial==6 then
      screen.text("rand lfo")
    end
  elseif uS.selectedPar==0 and params:get("expert mode")==1 then
    screen.move(x+10,y)
    tape_icon(x+10,y)
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
    screen.text(string.format("vol %1.1f",uP[uS.loopNum].vol))
  elseif uS.selectedPar==4 then
    screen.move(x+10,y)
    screen.text(string.format("rate %1.1f%%",uP[uS.loopNum].rate*100))
  elseif uS.selectedPar==5 then
    screen.move(x+10,y)
    screen.text(string.format("pan %1.1f",uP[uS.loopNum].pan))
  elseif uS.selectedPar==6 then
    screen.move(x+10,y)
    screen.text("reset every "..params:get(uS.loopNum.."reset every beat").." beat")
  elseif uS.selectedPar==7 then
    screen.move(x+10,y)
    screen.text("warble")
  end

  -- draw representation of current loop states
  for i=1,6 do
    if uS.loopNum==i then goto continue end
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
    if uS.recording[i]>0 then
      screen.circle(x,y,r+1)
    end
    screen.stroke()

    -- draw pixels at position if it has data or
    -- its being recorded/primed
    angle=360*(uP[i].loopLength-uP[i].position)/(uP[i].loopLength)+90
    if params:get(i.."isempty")==1 or i==uS.loopNum or uS.recording[i]>0 then
      for j=-1,1 do
        screen.pixel(x+(r-j)*math.sin(math.rad(angle)),y+(r-j)*math.cos(math.rad(angle)))
        screen.stroke()
      end
    end
    ::continue::
  end
  for i=1,6 do
    if uS.loopNum~=i then goto continue end
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
    if uS.recording[i]>0 then
      screen.circle(x,y,r+1)
    end
    screen.stroke()

    -- draw pixels at position if it has data or
    -- its being recorded/primed
    angle=360*(uP[i].loopLength-uP[i].position)/(uP[i].loopLength)+90
    if params:get(i.."isempty")==1 or i==uS.loopNum or uS.recording[i]>0 then
      for j=-1,1 do
        screen.pixel(x+(r-j)*math.sin(math.rad(angle)),y+(r-j)*math.cos(math.rad(angle)))
        screen.stroke()
      end
    end
    ::continue::
  end

  if uS.message~="" then
    screen.level(0)
    x=64
    y=28
    w=string.len(uS.message)*6
    screen.rect(x-w/2,y,w,10)
    screen.fill()
    screen.level(15)
    screen.rect(x-w/2,y,w,10)
    screen.stroke()
    screen.move(x,y+7)
    screen.text_center(uS.message)
  end

  screen.update()
end

--- Creates tape icon.
-- @tparam x {number}  X-coordinate of element
-- @tparam y {number}  Y-coordinate of element
-- from https://github.com/frederickk/b-b-b-b-beat
function tape_icon(x,y)
  local r=2

  screen.move(math.floor(x),math.floor(y)-4)
  screen.line_rel(1,0)
  screen.line_rel((r*5),0)

  for i=0,6,2 do
    screen.move(math.floor(x)+(r*i),math.floor(y)-4)
    screen.line_rel(0,1)
    screen.line_rel(0,r)
  end

  screen.move(math.floor(x),math.floor(y)+(r*2)-4)
  screen.line_rel(1,0)
  screen.line_rel(r,0)
  screen.move(math.floor(x)+(r*4),math.floor(y)+(r*2)-4)
  screen.line_rel(1,0)
  screen.line_rel(r,0)
  screen.stroke()
end

--
-- utils
--
function show_message(message)
  clock.run(function()
    uS.message=message
    redraw()
    clock.sleep(0.5)
    uS.message=""
    redraw()
  end)
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

function round_time_to_nearest_beat(t)
  seconds_per_qn=60/clock.get_tempo()
  remainder=t%seconds_per_qn
  if remainder==0 then
    return t
  end
  return t+seconds_per_qn-remainder
end
