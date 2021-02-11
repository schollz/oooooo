-- oooooo v1.5.0
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


engine.name="SimpleDelay"


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
  flagClearing={false,false,false,false,false,false,false},
  flagSpecial=0,
  message="",
  currentBeat=0,
  currentTime=0,
  lagActivated=false,
  timeSinceArming=0,
  lastOnset=0,
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
  pampfast=0.02,
  timeUntilLagInitiates=0.1,
  availableModes={"select one","default","stereo looping","delaylaylay"}
}

DATA_DIR=_path.data.."oooooo/"
PATH=_path.audio..'oooooo/'


function init()
  engine.delay(0.1)
  engine.volume(0.0)

  -- import kolor
  if util.file_exists("/home/we/dust/code/kolor") then 
  	-- local kolor = include("kolor/lib/kolor")
  	-- kolor:new()
  end

 --  -- import tmi
 --  if util.file_exists("/home/we/dust/code/tmi") then 
	-- local tmi = include("tmi/lib/tmi")
	-- local tmia = tmi:new()
 --  end

  -- import middy
  if util.file_exists("/home/we/dust/code/middy") then 
    -- local middy=include("middy/lib/middy")
    -- middy:init({filename='/home/we/dust/data/middy/maps/nanokontrol-oooooo2.json',device='nanokontrol'})
  end

  setup_sharing("oooooo")
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

  params:add_group("recording",9)
  params:add_control("pre level","pre level",controlspec.new(0,1,"lin",0.01,1,"",0.01))
  params:add_control("rec level","rec level",controlspec.new(0,1,"lin",0.01,1,"",0.01))
  params:add_control("rec thresh","rec thresh",controlspec.new(1,1000,'exp',1,85,'amp/10k'))
  params:set_action("rec thresh",update_parameters)
  params:add_control("vol pinch","vol pinch",controlspec.new(0,1000,'lin',1,30,'ms',1/1000))
  params:set_action("vol pinch",function(x)
    for i=1,6 do
      softcut.fade_time(i,x/1000+0.1)
      softcut.recpre_slew_time(i,x/1000)
    end
    update_parameters()
  end)
  params:add_option("catch transients w lag","catch transients w lag",{"no","yes"},1)
  params:set_action("catch transients w lag",update_parameters)
  params:add_option("rec thru loops","rec thru loops",{"no","yes"},1)
  params:set_action("rec thru loops",update_parameters)
  params:add_control("stop rec after","stop rec after",controlspec.new(1,64,"lin",1,1,"loops"))
  params:set_action("stop rec after",update_parameters)
  params:add_option("input type","input type",{"line-in L","line-in R","tape","line-in (L+R)+tape","split L/R+tape"},4)
  params:set_action("input type",function(x)
    update_softcut_input()
  end)
  params:add_option("sync lengths to first","sync lengths to first",{"no","yes"},1)
  params:set_action("sync lengths to first",update_parameters)

  params:add_group("save/load",3)
  params:add_text('save_name',"save as...","")
  params:set_action("save_name",function(y)
    -- prevent banging
    local x=y
    params:set("save_name","")
    if x=="" then
      do return end
    end
    -- save
    print(x)
    backup_save(x)
    params:set("save_message","saved as "..x)
  end)
  print("DATA_DIR "..DATA_DIR)
  local name_folder=DATA_DIR.."names/"
  print("name_folder: "..name_folder)
  params:add_file("load_name","load",name_folder)
  params:set_action("load_name",function(y)
    -- prevent banging
    local x=y
    params:set("load_name",name_folder)
    if #x<=#name_folder then
      do return end
    end
    -- load
    print("load_name: "..x)
    pathname,filename,ext=string.match(x,"(.-)([^\\/]-%.?([^%.\\/]*))$")
    print("loading "..filename)
    backup_load(filename)
    params:set("save_message","loaded "..filename..".")
  end)
  params:add_text('save_message',">","")


  params:add_group("all loops",8)
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
  params:add_option("continous rate","continous rate",{"no","yes"},1)
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

  -- add parameters
  filter_resonance=controlspec.new(0.05,1,'lin',0,1,'')
  filter_freq=controlspec.new(20,20000,'exp',0,20000,'Hz')
  for i=1,6 do
    params:add_group("loop "..i,35)
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
    params:add_control(i.."rate lfo period","rate lfo period",controlspec.new(0,60,"lin",0,0,"s",0.01/60))
    params:add_control(i.."rate lfo offset","rate lfo offset",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."pan","pan",controlspec.new(-1,1,"lin",0.01,0,"",0.01/2))
    params:add_control(i.."pan lfo amp","pan lfo amp",controlspec.new(0,1,"lin",0.01,0.2,"",0.01))
    params:add_control(i.."pan lfo period","pan lfo period",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."pan lfo offset","pan lfo offset",controlspec.new(0,60,"lin",0,0,"s",0.1/60))
    params:add_control(i.."reset every beat","reset every",controlspec.new(0,64,"lin",1,0,"beats"))
    params:add_option(i.."randomize on reset","randomize on reset",{"no","params","loops","both"},1)
    local loop_options = {"none"}
    for j=i+1,6 do 
      table.insert(loop_options,"loop "..j)
    end
    params:add_option(i.."sync tape with","sync tape with",loop_options,1)
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
    params:add{type='binary',name="play trig",id=i..'play trig',behavior='momentary',
      action=function(v)
        if v==1 then
          tape_play(i)
          uS.updateUI=true
        end
      end
    }
    params:add{type='binary',name="stop trig",id=i..'stop trig',behavior='momentary',
      action=function(v)
        if v==1 then
          tape_stop_reset(i)
          uS.updateUI=true
        end
      end
    }
    params:add{type='binary',name="recording trig",id=i..'recording trig',behavior='momentary',
      action=function(v)
        if v==1 then
          if uS.recording[i]>0 then
            tape_stop_rec(i)
          else
            tape_rec(i)
          end
          uS.updateUI=true
        end
      end
    }
    params:add{type='binary',name="arming trig",id=i..'arming trig',behavior='momentary',
      action=function(v)
        if v==1 then
          if uS.recording[i]>0 then
            tape_stop_rec(i)
          else
            tape_arm_rec(i)
          end
          uS.updateUI=true
        end
      end
    }
    params:add{type='binary',name="reset trig",id=i..'reset trig',behavior='momentary',
      action=function(v)
        if v==1 then
          if uS.recording[i]>0 then
            tape_stop_rec(i)
          end
          tape_reset(i)
          uS.updateUI=true
        end
      end
    }
    params:add_file(i.."load_file","load audio",_path.audio)
    params:set_action(i.."load_file",function(x)
      if #x<=#_path.audio then
        do return end
      end
      print("load_file",i,x)
      loop_load_wav(i,x)
      tape_play(i)
      uS.updateUI=true
    end)
    params:add_option(i.."isempty","is empty",{"false","true"},2)
    params:hide(i.."isempty")
  end

  params:add_option("choose mode","choose mode",uC.availableModes,1)
  params:add{type='binary',name="activate mode",id='activate mode',behavior='trigger',
    action=function(v)
      if params:get("choose mode") == 1 then 
        do return end 
      end
      activate_mode()
      uS.updateUI=true
    end
  }


  params_read_silent(DATA_DIR.."oooooo.pset")
  params:set('save_message',"")
  params:set('load_name',name_folder)

  init_loops(7)

  -- make data directory
  if not util.file_exists(PATH) then util.make_dir(PATH) end

  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=uC.updateTimerInterval
  timer.count=-1
  timer.event=update_timer
  timer:start()

  -- -- osc input
  -- osc.event = osc_in

  -- position poll
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()

  -- and initiate recording on incoming audio on input 1
  p_amp_in=poll.set("amp_in_l")
  -- set period low when primed, default 1 second
  p_amp_in.time=1
  p_amp_in.callback=function(val)
    for i=1,6 do
      if uS.recording[i]==1 and (params:get("input type")==1 or params:get("input type")>=4) then
        -- print("incoming signal = "..val)
        if val>params:get("rec thresh")/10000 then
          tape_rec(i)
        end
      end
    end
  end
  p_amp_in:start()

  -- and initiate recording on incoming on audio input 2
  p_amp_in2=poll.set("amp_in_r")
  -- set period low when primed, default 1 second
  p_amp_in2.time=1
  p_amp_in2.callback=function(val)
    for i=1,6 do
      if uS.recording[i]==1 and (params:get("input type")==2 or params:get("input type")>=4) then
        -- print("incoming signal = "..val)
        if val>params:get("rec thresh")/10000 then
          tape_rec(i)
        end
      end
    end
  end
  p_amp_in2:start()

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
    -- backup_load()
    if params:get("play on start")==2 then
      tape_play(7)
    end
  else
    for i=1,6 do
      tape_stop(i)
      tape_reset(i)
    end
  end

  update_softcut_input()
  update_softcut_input_lag(false)


  -- zack-specific
  -- tone down volume lfo amplitude
  randomize_lfos()
  for i=1,6 do
	  params:set(i.."vol lfo amp",0.1)
  end
  -- DEV comment this out
  -- params:set("choose mode",3)
  -- activate_mode()
end

function init_loops(j,ignore_pan)
  audio.level_adc(1) -- input volume 1
  audio.level_cut(1) -- Softcut master level (same as in LEVELS screen)

  i1=j
  i2=j
  if j==7 then
    i1=1
    i2=7
  end
  previous_uP = {table.unpack(uP)}
  for i=i1,i2 do
    print("initializing  "..i)
    uP[i]={}
    uP[i].loopStart=0
    uP[i].loopLength=(60/clock.get_tempo())*i*4
    if params:get("start length")>0 then
      uP[i].loopLength=(60/clock.get_tempo())*params:get("start length")
    end
    uP[i].loopUpdate=false
    uP[i].position=0
    uP[i].recordedLength=0
    uP[i].isStopped=true
    uP[i].vol=0.5
    uP[i].volUpdate=false
    uP[i].rate=1
    uP[i].rateUpdate=false
    if ignore_pan == nil or not ignore_pan then 
      uP[i].pan=0
    else
      uP[i].pan = previous_uP[i].pan
    end
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
      if ignore_pan == nil or not ignore_pan then 
        params:set(i.."pan",0)
      end
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
      softcut.pan(i,0)
      softcut.play(i,0)
      softcut.rate(i,1)
      softcut.loop_start(i,uC.bufferMinMax[i][2])
      softcut.loop_end(i,uC.bufferMinMax[i][2]+uP[i].loopLength)
      softcut.loop(i,1)
      softcut.rec(i,0)

      -- fade time is redundant with recpre
      -- softcut.fade_time(i,params:get("vol pinch")/1000)
      softcut.level_slew_time(i,params:get("slew rate"))
      softcut.rate_slew_time(i,params:get("slew rate"))
      softcut.recpre_slew_time(i,params:get("vol pinch")/1000)

      softcut.rec_level(i,params:get("rec level"))
      softcut.pre_level(i,params:get("pre level"))
      softcut.buffer(i,uC.bufferMinMax[i][1])
      softcut.position(i,uC.bufferMinMax[i][2])
      softcut.enable(i,1)
      softcut.phase_quant(i,0.025)

      softcut.post_filter_dry(i,0.0)
      softcut.post_filter_lp(i,1.0)
      softcut.post_filter_rq(i,1.0)
      softcut.post_filter_fc(i,20100)

      softcut.pre_filter_dry(i,1.0)
      softcut.pre_filter_lp(i,1.0)
      softcut.pre_filter_rq(i,1.0)
      softcut.pre_filter_fc(i,20100)
    end
  end
end

function activate_mode()
  print(uC.availableModes[params:get("choose mode")])
  if uC.availableModes[params:get("choose mode")]=="stereo looping" then 
    activate_mode_default()
    for i=1,6 do
      params:set(i.."pan",((i+1)%2+1)*2-3+math.floor(i/2)/10*(((i)%2+1)*2-3))
    end
    params:set("1sync tape with",2)
    params:set("3sync tape with",2)
    params:set("5sync tape with",2)
    params:set("input type",5)
  elseif uC.availableModes[params:get("choose mode")]=="delaylaylay" then 
    activate_mode_default()
    for i=1,5 do
      params:set(i.."sync tape with",2)
    end
    params:set("stop rec after",64)
    params:set("rec level",0.5)
    params:set("pre level",0.4)
    for i=1,6 do
      params:set(i.."length",math.random()*2)
      randomize_parameters(7)
      randomize_loops(7)
      randomize_lfos(7)
      tape_rec(i)
      params:set(i.."length lfo period",math.random()*30+5)
      params:set(i.."length lfo offset",math.random()*60)
    end
  elseif uC.availableModes[params:get("choose mode")]=="default" then 
    activate_mode_default()
  end
  params:set("choose mode",1)
end

function activate_mode_default()
  for i=1,6 do
    params:set(i.."sync tape with",1)
    tape_stop(i)
    tape_reset(i)
  end
  default_global_parameters = {
    ["pre level"]=1,
    ["rec level"]=1,
    ["rec thresh"]=85,
    ["catch transients w lag"]=1,
    ["rec thru loops"]=1,
    ["stop rec after"]=1,
    ["input type"]=4,
    ["sync lengths to first"]=1,
    ["pause lfos"]=1,
    ["destroy loops"]=0,
    ["vol ramp"]=0,
    ["randomize all on reset"]=1,
    ["reset all every"]=0,
    ["continous rate"]=1,
    ["slew rate"]=(60/clock.get_tempo())*4,
  }
  for k,v in pairs(default_global_parameters) do 
    params:set(k,v)
  end
  init_loops(7)
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
  for i=1,6 do
    if params:get("input type")==1 then
      -- print("input L only channel "..i)
      softcut.level_input_cut(1,i,1)
      softcut.level_input_cut(2,i,0)
      audio.level_adc_cut(1)
      audio.level_tape_cut(0)
    elseif params:get("input type")==2 then
      -- print("input R only channel "..i)
      softcut.level_input_cut(1,i,0)
      softcut.level_input_cut(2,i,1)
      audio.level_adc_cut(1)
      audio.level_tape_cut(0)
    elseif params:get("input type")==3 then
      print("tape only")
      audio.level_tape_cut(1)
      audio.level_adc_cut(0)
    elseif params:get("input type")==5 then
      -- print("stereo "..i)
      if i%2==0 then
        softcut.level_input_cut(1,i,1)
        softcut.level_input_cut(2,i,0)
      else
        softcut.level_input_cut(1,i,0)
        softcut.level_input_cut(2,i,1)
      end
      audio.level_adc_cut(1)
      audio.level_tape_cut(1)
    else
      -- print("tape+input L+R "..i)
      softcut.level_input_cut(1,i,1)
      softcut.level_input_cut(2,i,1)
      audio.level_adc_cut(1)
      audio.level_tape_cut(1)
    end
  end
end

function update_softcut_input_lag(on)
  if params:get("input type")==3 or on==uS.lagActivated then
    -- do nothing if using just tape or already activated
    do return end
  end
  uS.lagActivated=on
  if on then
    print("update_softcut_input_lag: activated")
    engine.volume(1.0)
    -- add lag to recording using a simple delay engine
    audio.level_monitor(0) -- turn off monitor to keep from hearing doubled audio
    audio.level_eng_cut(1)
    audio.level_adc_cut(0)
  else
    print("update_softcut_input_lag: deactivated")
    engine.volume(0.0)
    audio.level_monitor(1) -- turn on monitor
    audio.level_eng_cut(0)
    audio.level_adc_cut(1)
  end
end

function update_parameters(x)
  params:write(DATA_DIR.."oooooo.pset")
end

function update_positions(i,x)
  currentPosition=uP[i].position
  -- adjust position so it is relative to buffer start
  uP[i].position=x-uC.bufferMinMax[i][2]
  if currentPosition==uP[i].position then
    do return end
  end
  if uP[i].position<0 then
    uP[i].position=uP[i].loopStart
  end
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
      previousRecordingTime=uS.recordingTime[i]
      uS.recordingTime[i]=uS.recordingTime[i]+uC.updateTimerInterval
      if uS.recordingTime[i]>=uP[i].loopLength then
        uS.recordingLoopNum[i]=uS.recordingLoopNum[i]+1
        -- print("uS.recordingLoopNum[i]: "..uS.recordingLoopNum[i])
        if uS.recordingLoopNum[i]>=params:get("stop rec after") and uS.recordingLoopNum[i]<64 then
          -- stop recording when reached a full loop
          tape_stop_rec(i,false)
        else
          uS.recordingTime[i]=0
        end 
      elseif params:get("vol pinch") > 0 and uS.recordingTime[i]>=uP[i].loopLength/2 and previousRecordingTime<uP[i].loopLength/2 then 
      	clock.run(function()
      	   softcut_add_postroll(i)
      	end)
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
      if uP[i].vol>0 and params:get(i.."vol lfo period")>0 and params:get("pause lfos")==1 then
        uP[i].vol=uP[i].vol+params:get(i.."vol lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."vol lfo period"),params:get(i.."vol lfo offset"))
        uP[i].vol=util.clamp(uP[i].vol,0,1)
      end
      softcut.level(i,uP[i].vol)
    end
    if uP[i].rateUpdate or (params:get(i.."rate lfo period")>0 and params:get("pause lfos")==1 and params:get(i.."rate lfo amp")>0) or
      uP[i].rate~=(uC.discreteRates[params:get(i.."rate")]+params:get(i.."rate adjust"))*(params:get(i.."rate reverse")*2-3)/100.0 then
      uS.updateUI=true
      uP[i].rateUpdate=false
      local currentRateIndex=params:get(i.."rate")
      if params:get(i.."rate lfo period")>0 and params:get(i.."rate lfo amp")>0 and params:get("pause lfos")==1 then
        currentRateIndex=util.clamp(params:get(i.."rate lfo center")+round(util.linlin(-1,1,-#uC.discreteRates,#uC.discreteRates,params:get(i.."rate lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."rate lfo period"),params:get(i.."rate lfo offset")))),1,#uC.discreteRates)
        -- currentRateIndex=util.clamp(round(util.linlin(-1,1,0,1+#uC.discreteRates,params:get(i.."rate lfo amp")*calculate_lfo(uS.currentTime,params:get(i.."rate lfo period"),params:get(i.."rate lfo offset")))),1,#uC.discreteRates)
      end
      uP[i].rate=(uC.discreteRates[currentRateIndex]+params:get(i.."rate adjust"))*(params:get(i.."rate reverse")*2-3)/100.0
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
      if (uP[i].position<uP[i].loopStart or uP[i].position>uP[i].loopStart+uP[i].loopLength) then
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
function loop_load_wav(i,fname)
  -- loads fname into loop i
  local ch,samples,samplerate=audio.file_info(fname)
  local duration=samples/48000.0
  softcut.buffer_read_mono(fname,0,uC.bufferMinMax[i][2],uC.loopMinMax[2],1,uC.bufferMinMax[i][1])
  params:set(i.."rate adjust",100*samplerate/48000.0-100,true)
  params:set(i.."start",0,true)
  params:set(i.."length",duration,true)
  params:set(i.."isempty",1,true)
  uP[i].loopUpdate=true
end

function loop_save_wav(i,savename)
  buffernum=uC.bufferMinMax[i][1]
  pos_start=uC.bufferMinMax[i][2]+params:get(i.."start")
  softcut.buffer_write_mono(savename,pos_start,params:get(i.."length"),buffernum)
end

function backup_save(savename)
  -- create if doesn't exist
  os.execute("mkdir -p "..DATA_DIR.."names")
  os.execute("mkdir -p "..DATA_DIR..savename)
  os.execute("echo "..savename.." > "..DATA_DIR.."names/"..savename)

  -- save the parameter set
  params:write(DATA_DIR..savename.."/parameters.pset")

  -- save the user parameters
  tab.save(uP,DATA_DIR..savename.."/uP.txt")

  --
  -- iterate over each loop
  -- if not "isempty" then save it
  for i=1,6 do
    if params:get(i.."isempty")==1 then -- not empty
      loop_save_wav(i,DATA_DIR..savename.."/loop"..i..".wav")
    end
  end
end

function backup_load(savename)
  for i=1,6 do
    if util.file_exists(DATA_DIR..savename.."/loop"..i..".wav") then
      print("loading loop"..i)
      loop_load_wav(i,DATA_DIR..savename.."/loop"..i..".wav")
    end
  end
  params_read_silent(DATA_DIR..savename.."/parameters.pset")
  uP=tab.load(DATA_DIR..savename.."/uP.txt")
  for i=1,6 do
    if params:get(i.."isempty")==1 then
      tape_stop(i)
      tape_reset(i)
      tape_play(i)
    end
    uP[i].loopUpdate=true
    uP[i].panUpdate=true
    uP[i].rateUpdate=true
    uP[i].volUpdate=true
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
  print("tape_stop_reset "..j)
  -- sync with others first
  if j<7 and params:get(j.."sync tape with") > 1 then 
    tape_stop_reset(j+params:get(j.."sync tape with")-1)
  end
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
  if i<7 and params:get(i.."sync tape with") > 1 then 
    tape_reset(i+params:get(i.."sync tape with")-1)
  end
  if uP[i].position==uP[i].loopStart then
    do return end
  end
  print("tape_reset "..i)
  uP[i].position=uP[i].loopStart
  softcut.position(i,uC.bufferMinMax[i][2]+uP[i].loopStart)
  if params:get(i.."randomize on reset")>1 then
    if params:get(i.."randomize on reset")==2 then
      randomize_parameters(i)
    elseif params:get(i.."randomize on reset")==3 then
      randomize_loops(i)
    elseif params:get(i.."randomize on reset")==4 then
      randomize_parameters(i)
      randomize_loops(i)
    end
  end
end

function tape_stop(i)
  if i<7 and params:get(i.."sync tape with") > 1 then 
    tape_stop(i+params:get(i.."sync tape with")-1)
  end
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
  if i<7 and params:get(i.."sync tape with") > 1 then 
    tape_stop_rec(i+params:get(i.."sync tape with")-1,change_loop)
  end  
  if uS.recording[i]==0 then
    do return end
  end
  print("tape_stop_rec "..i)
  if uS.recording[i]==1 and (params:get("input type")==1 or params:get("input type")>=4) then
    p_amp_in.time=1
  elseif uS.recording[i]==1 and (params:get("input type")==2 or params:get("input type")>=4) then
    p_amp_in2.time=1
  end
  update_softcut_input_lag(false)
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
  softcut.rec_level(i,0)
  softcut.pre_level(i,1)
  clock.run(function()
    -- allow pre level to go down
    clock.sleep(params:get("vol pinch")/1000)
    softcut.rec(i,0)
    -- DEBUGGING PURPOSES
    -- loop_save_wav(i,"/tmp/save1.wav")
  end)


  -- change the loop size if specified
  print('params:get("rec thru loops") '..params:get("rec thru loops"))
  if not still_armed then
    if change_loop then
      params:set(i.."length",uP[i].recordedLength)
      uP[i].loopUpdate=true
      -- sync all the loops here if this is first loop and enabled
      if i==1 and params:get("sync lengths to first")==2 then
        for j=2,6 do
          uP[j].recordedLength=uP[1].recordedLength
          params:set(j.."length",uP[j].recordedLength)
          uP[j].loopUpdate=true
        end
      end
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
  if i<7 and params:get(i.."sync tape with") > 1 then 
    tape_clear(i+params:get(i.."sync tape with")-1)
  end
  print("tape_clear "..i)
  -- prevent double clear
  if uS.flagClearing[i] then
    do return end
  end
  -- signal clearing to prevent double clear
  clock.run(function()
    uS.flagClearing[i]=true
    uS.message="clearing"
    redraw()
    clock.sleep(0.5)
    uS.flagClearing[i]=false
    uS.message=""
    redraw()
  end)
  redraw()

  if i==7 then
    -- clear everything
    softcut.buffer_clear()
    for j=1,6 do
      if params:get(j.."isempty")==2 then
        init_loops(j,true)
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
      init_loops(i,true)
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
  if j<7 and params:get(j.."sync tape with") > 1 then 
    tape_play(j+params:get(j.."sync tape with")-1)
  end
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
  if i<7 and params:get(i.."sync tape with") > 1 then 
    tape_arm_rec(i+params:get(i.."sync tape with")-1)
  end
  if uS.recording[i]==1 then
    do return end
  end
  print("tape_arm_rec "..i)
  -- arm  recording
  uS.recording[i]=1
  if params:get("catch transients w lag")==2 then
    update_softcut_input_lag(true)
  end
  uS.recordingLoopNum[i]=0
  uS.timeSinceArming=clock.get_beats()*clock.get_beat_sec()
  -- monitor input
  if uS.recording[i]==1 and (params:get("input type")==1 or params:get("input type")>=4) then
    p_amp_in.time=uC.pampfast
  elseif uS.recording[i]==1 and (params:get("input type")==2 or params:get("input type")>=4) then
    p_amp_in2.time=uC.pampfast
  end
end

function tape_rec(i)
  if i<7 and params:get(i.."sync tape with") > 1 then 
    tape_rec(i+params:get(i.."sync tape with")-1)
  end
  if uS.recording[i]==2 then
    do return end
  end
  print("tape_rec "..i)
  if uP[i].isStopped then
    softcut.play(i,1)
    softcut.rate(i,uP[i].rate)
    uP[i].volUpdate=true
    uP[i].isStopped=false
  end
  if uS.recording[i]==1 and (params:get("input type")==1 or params:get("input type")>=4) then
    p_amp_in.time=1
  elseif uS.recording[i]==1 and (params:get("input type")==2 or params:get("input type")>=4) then
    p_amp_in2.time=1
  end
  uS.recordingTime[i]=0
  uS.recording[i]=2 -- recording is live
  params:set(i.."isempty",1)
  -- start recording
  softcut.rec_level(i,params:get("rec level"))
  softcut.pre_level(i,params:get("pre level"))
  softcut.rec(i,1)
  redraw()
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
      uS.flagSpecial=util.clamp(uS.flagSpecial+d,0,4)
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
      -- pause/start lfos
      if params:get("pause lfos")==1 then
        show_message("pausing lfos")
      else
        show_message("unpausing lfos")
      end
      params:set("pause lfos",3-params:get("pause lfos"))
    elseif uS.flagSpecial==2 then
      -- randomize!
      show_message("randomizing")
      randomize_parameters(7)
    elseif uS.flagSpecial==3 then
      -- randomize loops!
      show_message("randomizing loops")
      randomize_loops(7)
    elseif uS.flagSpecial==4 then
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
        if params:get(uS.loopNum.."rate lfo period")==0 then
          params:set(uS.loopNum.."rate lfo period",0.4)
        end
        if params:get(uS.loopNum.."rate lfo amp")==0 then
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
      if params:get("pause lfos")==1 then
        screen.text("pause lfos")
      else
        screen.text("unpause lfos")
      end
    elseif uS.flagSpecial==2 then
      screen.text("rand pars")
    elseif uS.flagSpecial==3 then
      screen.text("rand loop")
    elseif uS.flagSpecial==4 then
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
  local highlighted_loops = {uS.loopNum}
  -- highlight multiple
  while highlighted_loops[#highlighted_loops] > 0  and uS.loopNum ~= 7 do
    local next_loop = params:get(highlighted_loops[#highlighted_loops].."sync tape with")-1
    if next_loop > 0 then 
      next_loop = highlighted_loops[#highlighted_loops]+next_loop
    end
    table.insert(highlighted_loops,next_loop)
  end

  for i=1,6 do
    if has_value(highlighted_loops,i) then goto continue end
    -- draw circles
    r=(uC.radiiMinMax[2]-uC.radiiMinMax[1])*uP[i].loopLength/(uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2])+uC.radiiMinMax[1]
    if r>45 then
      r=45
    end
    x=uC.centerOffsets[i][1]+(uC.widthMinMax[2]-uC.widthMinMax[1])*(uP[i].pan+1)/2+uC.widthMinMax[1]
    y=uC.centerOffsets[i][2]+(uC.heightMinMax[2]-uC.heightMinMax[1])*(1-uP[i].vol)+uC.heightMinMax[1]
    if has_value(highlighted_loops,i) then
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
    angle=-1*360*(uP[i].position-uP[i].loopStart)/(uP[i].loopLength)+90
    if params:get(i.."isempty")==1 or i==uS.loopNum or uS.recording[i]>0 then
      for j=-1,1 do
        screen.pixel(x+(r-j)*math.sin(math.rad(angle)),y+(r-j)*math.cos(math.rad(angle)))
        screen.stroke()
      end
    end
    ::continue::
  end
  for i=1,6 do
    if not has_value(highlighted_loops,i) then goto continue end
    -- draw circles
    r=(uC.radiiMinMax[2]-uC.radiiMinMax[1])*uP[i].loopLength/(uC.bufferMinMax[i][3]-uC.bufferMinMax[i][2])+uC.radiiMinMax[1]
    if r>45 then
      r=45
    end
    x=uC.centerOffsets[i][1]+(uC.widthMinMax[2]-uC.widthMinMax[1])*(uP[i].pan+1)/2+uC.widthMinMax[1]
    y=uC.centerOffsets[i][2]+(uC.heightMinMax[2]-uC.heightMinMax[1])*(1-uP[i].vol)+uC.heightMinMax[1]
    if has_value(highlighted_loops,i) then
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
    angle=-1*360*(uP[i].position-uP[i].loopStart)/(uP[i].loopLength)+90
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

function has_value (tab, val)
  for index, value in ipairs(tab) do
      if value == val then
          return true
      end
  end
  return false
end


function softcut_add_postroll(i)
    if params:get("stop rec after") == 64 then do return end end
    src_ch=uC.bufferMinMax[i][1]
    dst_ch=src_ch
    start_src=uP[i].loopStart+uC.bufferMinMax[i][2]
    start_dst=uP[i].loopStart+uC.bufferMinMax[i][2]+uP[i].loopLength
    dur=uP[i].loopLength/2
    if dur>1 then
      dur=1
    end
    fade_time=0
    reverse=0
    softcut.buffer_copy_mono(src_ch,dst_ch,start_src,start_dst,dur,fade_time,reverse)
    print("copied buffer to post roll")
end

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

local function unquote(s)
  return s:gsub('^"',''):gsub('"$',''):gsub('\\"','"')
end

function rerun()
  norns.script.load(norns.state.script)
end

params_read_silent=function(fname)

  fh,err=io.open(fname)
  if err then print("no file");return;end
  while true do
    line=fh:read()
    if line==nil then break end
    local par_name,par_value=string.match(line,"(\".-\")%s*:%s*(.*)")
    if par_name and par_value then
      par_name=unquote(par_name)
      if type(tonumber(par_value))=="number" then
        par_value=tonumber(par_value)
      elseif par_value=="-inf" then
        par_value=-1*math.huge
      elseif par_value=="inf" then
        par_value=math.huge
      end
      pcall(function() params:set(par_name,par_value,true) end)
    else
      print(par_name,par_value)
    end
  end
  fh:close()
end

function setup_sharing(script_name)
  if not util.file_exists(_path.code.."norns.online") then
    print("need to donwload norns.online")
    do return end
  end

  local share=include("norns.online/lib/share")

  -- start uploader with name of your script
  local uploader=share:new{script_name=script_name}
  if uploader==nil then
    print("uploader failed, no username?")
    do return end
  end

  -- add parameters
  params:add_group("SHARE",4)

  -- uploader (CHANGE THIS TO FIT WHAT YOU NEED)
  -- select a save
  local names_dir=DATA_DIR.."names/"
  params:add_file("share_upload","upload",names_dir)
  params:set_action("share_upload",function(y)
    -- prevent banging
    local x=y
    params:set("share_download",names_dir)
    if #x<=#names_dir then
      do return end
    end


    -- choose data name
    -- (here dataname is from the selector)
    local dataname=share.trim_prefix(x,DATA_DIR.."names/")
    params:set("share_message","uploading...")
    _menu.redraw()
    print("uploading "..x.." as "..dataname)

    -- upload each loop
    local pathtofile=""
    local target=""
    for i=1,6 do
      pathtofile=DATA_DIR..dataname.."/loop"..i..".wav"
      target=DATA_DIR..uploader.upload_username.."-"..dataname.."/loop"..i..".wav"
      if util.file_exists(pathtofile) then
        msg=uploader:upload{dataname=dataname,pathtofile=pathtofile,target=target}
        if not string.match(msg,"OK") then
          params:set("share_message",msg)
          do return end
        end
      end
    end

    -- upload paramset
    pathtofile=DATA_DIR..dataname.."/parameters.pset"
    target=DATA_DIR..uploader.upload_username.."-"..dataname.."/parameters.pset"
    uploader:upload{dataname=dataname,pathtofile=pathtofile,target=target}

    -- upload uP
    pathtofile=DATA_DIR..dataname.."/uP.txt"
    target=DATA_DIR..uploader.upload_username.."-"..dataname.."/uP.txt"
    uploader:upload{dataname=dataname,pathtofile=pathtofile,target=target}

    -- upload name file
    pathtofile=DATA_DIR.."names/"..dataname
    target=DATA_DIR.."names/"..uploader.upload_username.."-"..dataname
    uploader:upload{dataname=dataname,pathtofile=pathtofile,target=target}

    -- goodbye
    params:set("share_message","uploaded.")
  end)

  -- downloader
  download_dir=share.get_virtual_directory(script_name)
  params:add_file("share_download","download",download_dir)
  params:set_action("share_download",function(y)
    -- prevent banging
    local x=y
    params:set("share_download",download_dir)
    if #x<=#download_dir then
      do return end
    end

    -- download
    print("downloading!")
    params:set("share_message","downloading...")
    _menu.redraw()
    local msg=share.download_from_virtual_directory(x)
    params:set("share_message",msg)
  end)
  params:add{type='binary',name='refresh directory',id='share_refresh',behavior='momentary',action=function(v)
    print("updating directory")
    params:set("share_message","refreshing directory.")
    _menu.redraw()
    share.make_virtual_directory()
    params:set("share_message","directory updated.")
  end
}
params:add_text('share_message',">","")
end



-- --
-- -- osc
-- --
-- function osc_in(path, args, from)
--   if path == "onset" then
--     cur_onset = args[2]
--     print("onset "..cur_onset)
--     if (cur_onset-uS.lastOnset) < 0.5 then
--       do return end
--     end
--     print("onset detected")
--     uS.lastOnset = cur_onset
--     for i=1,6 do
--       if uS.recording[i]==1 and (params:get("input type")==1 or params:get("input type")==4) then
--           tape_rec(i)
--       end
--     end
--   end
-- end
