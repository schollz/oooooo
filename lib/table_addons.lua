function table.reverse(t)
  local len=#t
  for i=len-1,1,-1 do
    t[len]=table.remove(t,i)
  end
end

function table.get_rotation(t)
  local t2={}
  local v1=0
  for i,v in ipairs(t) do
    if i>1 then
      table.insert(t2,v)
    else
      v1=v
    end
  end
  table.insert(t2,v1)
  return t2
end

function table.rotate(t)
  for i,v in ipairs(table.get_rotation(t)) do
    t[i]=v
  end
end

function table.clone(org)
  return {table.unpack(org)}
end

function table.copy(t)
  local t2={}
  for i,v in ipairs(t) do
    table.insert(t2,v)
  end
  return t2
end

function table.print(t)
  for i,v in ipairs(t) do
    print(i,v)
  end
end

function table.print_matrix(m)
  for _,v in ipairs(m) do
    local s=""
    for _,v2 in ipairs(v) do
      s=s..v2.." "
    end
    print(s)
  end
end

function table.get_change(m)
  local total_change=0
  for col=1,#m[1] do
    local last_val=0
    for row=1,#m do
      local val=m[row][col]
      if row>1 then
        total_change=total_change+math.abs(val-last_val)
      end
      last_val=val
    end
  end
  return total_change
end

function table.minimize_row_changes(m)
  local m_=table.clone(m)
  -- generate random rotations
  local best_change=100000
  local best_m={}
  for i=1,10000 do
    -- rotate a row randomly
    local random_row=math.random(1,#m)
    m_[random_row]=table.get_rotation(m_[random_row])
    local change=table.get_change(m_)
    if change<best_change then
      best_change=change
      best_m=table.clone(m_)
    end
  end
  return best_m
  -- table.print_matrix(best_m)
end

function table.smallest_modded_rot(t1,t2,mod)
  local t1_diff=0
  t1_diff=t1[1]-(t1[1]%mod)

  local t2_mod={}
  for i,v in ipairs(t2) do
    table.insert(t2_mod,v%mod)
  end
  table.sort(t2_mod)

  -- higher inversions
  t_rots={}
  t2_mod_=table.copy(t2_mod)
  table.insert(t_rots,table.copy(t2_mod_))
  for i=1,2 do
    -- print(i)
    -- table.print(t2_mod_)
    table.rotate(t2_mod_)
    t2_mod_[#t2_mod_]=t2_mod_[#t2_mod_]+12
    table.insert(t_rots,table.copy(t2_mod_))
  end
  -- lower inversions
  t2_mod_=table.copy(t2_mod)
  table.reverse(t2_mod_)
  for i=1,2 do
    table.rotate(t2_mod_)
    t2_mod_[#t2_mod_]=t2_mod_[#t2_mod_]-12
    table.insert(t_rots,table.copy(t2_mod_))
  end

  -- sorting
  for i,_ in ipairs(t_rots) do
    table.sort(t_rots[i])
    for j,_ in ipairs(t_rots[i]) do
      t_rots[i][j]=t_rots[i][j]+t1_diff
    end
  end

  -- find the smallest change
  local best_change=10000
  local best_t2={}
  for i,t_ in ipairs(t_rots) do
    local score=table.get_change({t1,t_})
    -- print(i)
    -- table.print(t_)
    -- table.print(t1)
    -- print("score",score)
    if score<best_change then
      best_change=score
      best_t2=t_
    end
  end
  -- print("best")
  -- table.print(best_t2)
  return best_t2
end
