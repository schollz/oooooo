-- hoooooops v0.1
-- six mono tape reels
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

-- user parameters
uP={
  -- initialized in init
}

-- user state
uS={
  updateUI=false,
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
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
    {0,0},
  },
  parms={"loopstart","loopend","vol","rate","pan"},
}

PATH=_path.audio..'hoops/'

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
  
  -- make data directory
  if not util.file_exists(PATH) then util.make_dir(PATH) end
  
  -- load buffer from file
  if util.file_exists(PATH.."hoops.wav") then
    softcut.buffer_read_stereo(PATH.."hoops.wav",0,0,-1)
  end
  -- TODO: load parameters from file?
  
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
      else
        -- save tape
        softcut.buffer_write_stereo(PATH.."hoops.wav",0,-1)
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
    uP[i].loopStart=util.clamp(uP[i].loopStart+lstart/10,0,uC.loopMinMax[2])
    uP[i].loopLength=util.clamp(uP[i].loopLength+llength/10,0,uC.loopMinMax[2])
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
end

function tape_delta_volume(n,x)
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
  end
  for i=i1,i2 do
    uP[i].vol=util.clamp(uP[i].vol+x/100,0,1)
    softcut.level(i,uP[i].vol)
  end
end

function tape_delta_rate(n,x)
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
  end
  for i=i1,i2 do
    uP[i].rate=util.clamp(uP[i].rate+x/10,-4,4)
    softcut.rate(i,uP[i].rate)
  end
end

function tape_delta_pan(n,x)
  i1=1
  i2=6
  if n>0 then
    i1=n
    i2=n
  end
  for i=i1,i2 do
    uP[i].pan=util.clamp(uP[i].pan+x/10,-1,1)
    softcut.pan(i,uP[i].pan)
  end
end

--
-- encoders
--
function enc(n,d)
  if n==1 then
    uS.loopNum=util.clamp(uS.loopNum+d,1,6)
  elseif n==2 then
    uS.selectedPar=utils.clamp(uS.selectedPar+d,1,5)
  elseif n==3 then
    if uS.selectedPar==1 then
      tape_change_loop(uS.loopNum,d,0)
    elseif uS.selectedPar==2 then
      tape_change_loop(uS.loopNum,0,d)
    elseif uS.selectedPar==3 then
      tape_delta_volume(uS.loopNum,d)
    elseif uS.selectedPar==4 then
      tape_delta_rate(uS.loopNum,d)
    elseif uS.selectedPar==5 then
      tape_delta_pan(uS.loopNum,d)
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
  screen.text("oooooo")
  
  -- show recording symbol
  if uP[uS.loopNum].isRecording then
    screen.move(70,8)
    screen.text("REC")
  end
  
  -- show loop info
  x=2
  y=16
  screen.move(x,y)
  screen.text(uS.loopNum)
  
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
    r=(uC.radiiMinMax[2]-uC.radiiMinMax[1])*uP[i].vol+uC.radiiMinMax[1]
    x=uC.centerOffsets[i][1]+(uC.widthMinMax[2]-uC.heightMinMax[1])*(uP[i].pan+1)/2+uC.widthMinMax[1]
    y=uC.centerOffsets[i][2]+(uC.heightMinMax[2]-uC.widthMinMax[1])*(uP[i].rate+4)/8+uC.heightMinMax[1]
    if uS.loopNum==0 or uS.loopNum==i then
      screen.level(15)
    else
      screen.level(5)
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
-- json library
--
--[[ json.lua
 
A compact pure-Lua JSON library.
The main functions are: json.stringify, json.parse.
 
## json.stringify:
 
This expects the following to be true of any tables being encoded:
 * They only have string or number keys. Number keys must be represented as
   strings in json; this is part of the json spec.
 * They are not recursive. Such a structure cannot be specified in json.
 
A Lua table is considered to be an array if and only if its set of keys is a
consecutive sequence of positive integers starting at 1. Arrays are encoded like
so: `[2, 3, false, "hi"]`. Any other type of Lua table is encoded as a json
object, encoded like so: `{"key1": 2, "key2": false}`.
 
Because the Lua nil value cannot be a key, and as a table value is considerd
equivalent to a missing key, there is no way to express the json "null" value in
a Lua table. The only way this will output "null" is if your entire input obj is
nil itself.
 
An empty Lua table, {}, could be considered either a json object or array -
it's an ambiguous edge case. We choose to treat this as an object as it is the
more general type.
 
To be clear, none of the above considerations is a limitation of this code.
Rather, it is what we get when we completely observe the json specification for
as arbitrary a Lua object as json is capable of expressing.
 
## json.parse:
 
This function parses json, with the exception that it does not pay attention to
\u-escaped unicode code points in strings.
 
It is difficult for Lua to return null as a value. In order to prevent the loss
of keys with a null value in a json string, this function uses the one-off
table value json.null (which is just an empty table) to indicate null values.
This way you can check if a value is null with the conditional
`val == json.null`.
 
If you have control over the data and are using Lua, I would recommend just
avoiding null values in your data to begin with.
 
--]]

local json={}

-- Internal functions.

local function kind_of(obj)
  if type(obj)~='table' then return type(obj) end
  local i=1
  for _ in pairs(obj) do
    if obj[i]~=nil then i=i+1 else return 'table' end
  end
  if i==1 then return 'table' else return 'array' end
end

local function escape_str(s)
  local in_char={'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end
 
-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end
 
-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"'  then return val, pos + 1 end
  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
  -- We must have a \ character.
  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end
 
-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos .. '.') end
  return val, pos + #num_str
end
 
 
-- Public values and functions.
 
function json.stringify(obj, as_key)
  local s = {}  -- We'll build the string as an array of strings to be concatenated.
  local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.
  if kind == 'array' then
    if as_key then error('Can\'t encode array as key.') end
    s[#s + 1] = '['
    for i, val in ipairs(obj) do
      if i > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = json.stringify(val)
    end
    s[#s + 1] = ']'
  elseif kind == 'table' then
    if as_key then error('Can\'t encode table as key.') end
    s[#s + 1] = '{'
    for k, v in pairs(obj) do
      if #s > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = json.stringify(k, true)
      s[#s + 1] = ':'
      s[#s + 1] = json.stringify(v)
    end
    s[#s + 1] = '}'
  elseif kind == 'string' then
    return '"' .. escape_str(obj) .. '"'
  elseif kind == 'number' then
    if as_key then return '"' .. tostring(obj) .. '"' end
    return tostring(obj)
  elseif kind == 'boolean' then
    return tostring(obj)
  elseif kind == 'nil' then
    return 'null'
  else
    error('Unjsonifiable type: ' .. kind .. '.')
  end
  return table.concat(s)
end
 
json.null = {}  -- This is a one-off table to represent the null value.
 
function json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == '{' then  -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
      obj[key], pos = json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = json.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '"' then  -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then  -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then  -- End of an object or array.
    return nil, pos + 1
  else  -- Parse true, false, or null.
    local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
    error('Invalid json syntax starting at ' .. pos_info_str)
  end
end
 
 

   