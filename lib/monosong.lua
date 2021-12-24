include("oooooo/lib/table_addons")
local MusicUtil=require("oooooo/lib/musicutil")
local lattice_=include("oooooo/lib/lattice")
local s=require("sequins")

local Monosong={}

function Monosong:new (o)
  o=o or {} -- create object if user does not provide one
  setmetatable(o,self)
  self.__index=self
  self.lattice=lattice_:new()
  self.midis={}
  for _,dev in pairs(midi.devices) do
    local name=string.lower(dev.name)
    name=name:gsub("-","")
    print("connected to "..name)
    self.midis[name]={last_note=nil}
    self.midis[name].conn=midi.connect(dev.port)
  end

  -- setup parameters
  params:add_separator("chord layering")
  params:add{type='binary',name="activate",id='activate sequencer',behavior='toggle',
    action=function(v)
      if v==1 then 
        for i=1,params:get("loops to record") do 
          params:set(i.."length",(60/clock.get_tempo())*16)
        end
        monosong:play()
      else
        monosong:stop()
      end
    end
  }
  params:add{type="number",id="root note",name="root note",min=0,max=127,default=48,formatter=function(param) return MusicUtil.note_num_to_name(param:get(),true) end}
  self.available_chords={"I","ii","iii","IV","V","vi","VII","i","II","III","iv","v","VI","vii"}
  local available_chords_default={6,4,1,5}
  for i=1,4 do 
    params:add_option("chord"..i,"chord "..i,self.available_chords,available_chords_default[i])
  end
  self.available_octave_sequences={
    "+1 0 -1 +2 +1 0",
    "0 0 -1 0 +1 +2",
    "0 0 -1 +2 +1",
    "-1 0 +1 +2 +3",
    "+1 0 -1 +2 +1 +3",
    "+1 +2 0 +1 -1 -2",
  }
  params:add_option("octave sequence","octave",self.available_octave_sequences,1)
  params:add{type="number",id="loops to record",name="loops to record",min=1,max=6,default=6}
  params:add_control("solo probability","solo probability",controlspec.new(0,100,"lin",1,5,"%",1/100))
  params:add_control("gate length","gate length (crow2)",controlspec.new(0,100,"lin",1,75,"%",1/100))
  params:add{type="number",id="po clock start",name="po clock start (crow3)",min=1,max=6,default=5}
  
  return o
end

function Monosong:play()
  self.root_note=params:get("root note")
  self.root_scale="Major"
  self.chord_progression={}
  for i=1,4 do 
    table.insert(self.chord_progression,self.available_chords[params:get("chord"..i)])
  end
  self.octave_seq={}
  local octave_seq_foo={}
  local ss=self.available_octave_sequences[params:get("octave sequence")]
  local delimiter=" "
  for match in (ss..delimiter):gmatch("(.-)"..delimiter) do
    if match=="+1" then 
      table.insert(octave_seq_foo,12)
    elseif match=="0" then 
      table.insert(octave_seq_foo,0)
    elseif match=="-1" then 
      table.insert(octave_seq_foo,-12)
    elseif match=="+2" then 
      table.insert(octave_seq_foo,24)
    elseif match=="-2" then 
      table.insert(octave_seq_foo,-24)
    end
  end
  tab.print(octave_seq_foo)
  table.insert(octave_seq_foo,s{36}:count(100))
  self.octave_seq=s(octave_seq_foo)

  self.octave_current=0

  -- TODO: these might be made to be optional...
  print("chord changes before:")
  self.chords={}
  for _,v in ipairs(self.chord_progression) do
    table.insert(self.chords,MusicUtil.generate_chord_roman(self.root_note,self.root_scale,v))
  end
  table.print_matrix(self.chords)
  self:minimize_transposition()
  self:minimize_changes()
  print("chord changes after:")
  table.print_matrix(self.chords)

  -- create chord index
  local foo={}
  for i,_ in ipairs(self.chords) do
    table.insert(foo,i)
  end
  self.chord_index=s(foo)
  self.chord_index_current=1

  -- create the chord sequences
  self.chord_seq={}
  for _,notes in ipairs(self.chords) do
    table.insert(self.chord_seq,s(notes))
  end

  -- startup some lattices
  self.lattice=lattice_:new()
  local phrase_count=0
  local change_octave=false
  self.pattern_phrase=self.lattice:new_pattern{
    action=function(x)
      self.octave_current=self.octave_seq()
      phrase_count=phrase_count+1
      if phrase_count<=params:get("loops to record") then
        print("recording on "..phrase_count)
        uS.loopNum=phrase_count
        params:set(phrase_count.."recording trig",1)
        clock.run(function()
          clock.sleep(0.1)
          params:set(phrase_count.."recording trig",0)
        end)
      elseif phrase_count==params:get("loops to record")+1 then 
        uS.flagSpecial=5
        uS.loopNum=phrase_count
      end
    end,
    division=4,
  }
  self.pattern_chord=self.lattice:new_pattern{
    action=function(x)
      -- iterate chord index
      self.chord_index_current=self.chord_index()
      local note=self.chord_seq[self.chord_index_current]()+self.octave_current
      if phrase_count<=params:get("loops to record") then 
        self:play_note(note,1)
      end
    end,
    division=1,
  }
  -- crow output 3 is for synchronzing pocket operators
  crow.output[3].action = "{ to(0,0), to(1,0.015), to(0,0) }"
  self.pattern_posync=self.lattice:new_pattern{
    action=function(x)
      if phrase_count>=params:get("po clock start") then 
        crow.output[3]()
      end
    end,
    division=1/8,
  }
  self.pattern_solo=self.lattice:new_pattern{
    action=function(x)
      if phrase_count>params:get("loops to record") and math.random()<(params:get("solo probability")/100) then
        self.octave_current=self.octave_seq()
        local note=self.chord_seq[self.chord_index_current]()+self.octave_current
        self:play_note(note,1/16)
      end
    end,
    division=1/16,
  }
  clock.run(function()
    clock.sleep(1)
    self.lattice:start()
  end)
end

function Monosong:play_note(note,division)
  local gate_length=clock.get_beat_sec()*division*params:get("gate length")/100
  if crow~=nil then 
    crow.output[2].action = "{ to(0,0), to(5,"..gate_length.."), to(0,0) }"
    crow.output[2]()
    crow.output[1].volts=(note-24)/12
  end
  for name,m in pairs(self.midis) do
    if m.last_note~=nil then
      m.conn:note_off(m.last_note)
    end
    m.conn:note_on(note,64)
    self.midis[name].last_note=note
  end
end

function Monosong:stop()
  self.lattice:destroy()
end

-- minimize_transposition transposes each chord for minimal distance
function Monosong:minimize_transposition()
  for i,chord in ipairs(self.chords) do
    if i>1 then
      self.chords[i]=table.smallest_modded_rot(current_chord,chord,12)
    end
    while table.average(self.chords[i])-self.root_note>12 do
      for j,_ in ipairs(self.chords[i]) do 
        self.chords[i][j]=self.chords[i][j]-12 
      end
    end
    while table.average(self.chords[i])-self.root_note<-12 do
      for j,_ in ipairs(self.chords[i]) do 
        self.chords[i][j]=self.chords[i][j]+12
      end
    end
    current_chord=self.chords[i]
  end
  -- make sure chords are around root
end

-- rotates order of notes in chord to monosong playing
function Monosong:minimize_changes()
  self.chords=table.minimize_row_changes(self.chords)
end

return Monosong
