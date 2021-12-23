include("oooooo/lib/table_addons")
local MusicUtil=require("musicutil")
local lattice_=require("lattice")
local s=require("sequins")

local Monosong={}

function Monosong:new (o)
  o=o or {} -- create object if user does not provide one
  setmetatable(o,self)
  self.__index=self
  self.root_note=32
  self.root_scale="Major"
  self.chord_progression={"vi","IV","I","V"}
  self.octave_seq=s{12,0,-12,24,12,0,s{36}:count(1000)}
  self.octave_current=0
  self.lattice=lattice_:new()
  if pcall(function () params:get("1recording trig") end) then
    self.oooooo=true
    print("in oooooo")
  else
    self.oooooo=false
    print("not in oooooo")
  end
return o
end

function Monosong:play()
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
  self.pattern_chord=self.lattice:new_pattern{
    action=function(x)
      -- iterate chord index
      self.chord_index_current=self.chord_index()
      local note=self.chord_seq[self.chord_index_current]()+self.octave_current
      if crow~=nil and phrase_count<7 then 
        crow.output[1].volts=(note-24)/12
      end
      print("note",note)
      if change_octave then 
        self.octave_current=self.octave_seq()
        print("octave",self.octave_current)
        change_octave=false
      end
    end,
    division=1,
  }
  self.pattern_phrase=self.lattice:new_pattern{
    action=function(x)
      change_octave=true
      phrase_count=phrase_count+1
      if self.oooooo then
        if phrase_count<7 then
          print("recording on "..phrase_count)
          uS.loopNum=phrase_count
          params:set(phrase_count.."recording trig",1)
          clock.run(function()
            clock.sleep(0.1)
            params:set(phrase_count.."recording trig",0)
          end)
        end
      end
    end,
    division=4,
  }
  self.pattern_solo=self.lattice:new_pattern{
    action=function(x)
      if self.oooooo then
        if phrase_count>6 and math.random()<0.05 then
          self.octave_current=self.octave_seq()
          local note=self.chord_seq[self.chord_index_current]()+self.octave_current
          if crow~=nil then 
            crow.output[1].volts=(note-24)/12
          end
        end
      end
    end,
    division=1/16,
  }
  clock.run(function()
    clock.sleep(1)
    self.lattice:start()
  end)
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
    current_chord=self.chords[i]
  end
end

-- rotates order of notes in chord to monosong playing
function Monosong:minimize_changes()
  self.chords=table.minimize_row_changes(self.chords)
end

return Monosong
