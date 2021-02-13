local Glyphs={}
local json=include("oooooo/lib/json")
local f=io.open(_path.code.."oooooo/lib/glyphs.json","rb")
local content=f:read("*all")
f:close()

local glyphs=json.decode(content)


function Glyphs.pixels(name)
  pixels={}
  for i=1,#name do
    if i==5 then
      break
    end
    letter=name:sub(i,i)
    for _,glyph in ipairs(glyphs) do
      if glyph.glyph==letter then
        for _,position in ipairs(glyph.positions) do
          table.insert(pixels,{position.y+1,position.x+(i-1)*4+1,15})
        end
        break
      end
    end
  end


  return pixels
end

return Glyphs
