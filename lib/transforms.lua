-- Transforms
-- Four transformation pairs for Thorns

local Transforms = {}

-- Transformation types
Transforms.PITCH_MOD = 1
Transforms.VELOCITY_MOD = 2
Transforms.MUTATE = 3
Transforms.GATE_CHAOS = 4
Transforms.TIME_SHIFT = 5

-- Generate random parameters for a transformation
function Transforms.generate_params(transform_type, pattern_length, gate_chaos_prob, mutation_prob, shift_freedom)
  local params = {
    type = transform_type
  }
  
  if transform_type == Transforms.PITCH_MOD then
    -- Random exponent between 1 and 2 for power function
    params.g = 1.0 + math.random()
    
  elseif transform_type == Transforms.VELOCITY_MOD then
    -- Random exponent between 1 and 10 for power function
    params.g = 1.0 + math.random() * 9.0
    
  elseif transform_type == Transforms.MUTATE then
    -- For each step, choose shifts for both pitch and velocity
    params.pitch_shifts = {}
    params.velocity_shifts = {}
    for i = 1, pattern_length do
      local r = math.random()
      if r < mutation_prob / 2 then
        params.pitch_shifts[i] = 1 -- +1 semitone
      elseif r < mutation_prob then
        params.pitch_shifts[i] = -1 -- -1 semitone
      else
        params.pitch_shifts[i] = 0 -- no change
      end
      
      local v = math.random()
      if v < mutation_prob / 2 then
        params.velocity_shifts[i] = 8 -- +8 velocity
      elseif v < mutation_prob then
        params.velocity_shifts[i] = -8 -- -8 velocity
      else
        params.velocity_shifts[i] = 0 -- no change
      end
    end
    
  elseif transform_type == Transforms.GATE_CHAOS then
    -- Which steps get affected, plus random pitch/vel for new notes
    params.affected_steps = {}
    params.new_pitches = {}
    params.new_velocities = {}
    
    for i = 1, pattern_length do
      if math.random() < gate_chaos_prob then
        params.affected_steps[i] = true
        params.new_pitches[i] = math.floor(math.random() * 24) -- 0-23
        params.new_velocities[i] = math.floor(math.random() * 128) -- 0-127
      end
    end
    
  elseif transform_type == Transforms.TIME_SHIFT then
    -- Weighted shift selection based on shift_freedom
    local x = shift_freedom
    local n = pattern_length
    
    -- Handle edge case: x = 0 means no shift
    if x < 0.001 then
      params.shift = 0
      params.reverse = false
    -- Handle edge case: x = 1 means uniform distribution
    elseif x > 0.999 then
      params.shift = math.random(0, n)
      params.reverse = (params.shift == n)
      if not params.reverse then
        -- params.shift already set
      end
    else
      -- Use weighted distribution: P(m) = x^m * (x-1)/(x^(n+1)-1)
      -- Compute cumulative probabilities
      local cumulative = {}
      local normalizer = (x - 1) / (math.pow(x, n + 1) - 1)
      local sum = 0
      for m = 0, n do
        sum = sum + math.pow(x, m) * normalizer
        cumulative[m] = sum
      end
      
      -- Sample using inverse transform
      local r = math.random()
      params.shift = 0
      for m = 0, n do
        if r <= cumulative[m] then
          params.shift = m
          break
        end
      end
      
      params.reverse = (params.shift == n)
    end
  end
  
  return params
end

-- Apply transformation A (left branch)
function Transforms.apply_a(sequence, params, pattern_length)
  local result = {}
  
  for i = 1, pattern_length do
    result[i] = {
      pitch = sequence[i].pitch,
      velocity = sequence[i].velocity,
      original_gate = sequence[i].original_gate,
      current_gate = sequence[i].current_gate
    }
  end
  
  if params.type == Transforms.PITCH_MOD then
    -- Pitch mod: power function transformation
    for i = 1, pattern_length do
      local pitch = result[i].pitch
      local r = pitch - 8 -- relative to base (-8 to 15)
      local p = (r - 3.5) / 12 -- scaled relative pitch
      
      local transformed_p
      if p > 0 then
        transformed_p = math.pow(p, params.g)
      elseif p < 0 then
        transformed_p = -1 * math.pow(-p, params.g)
      else
        transformed_p = 0
      end
      
      local transformed_r = 3.5 + 12 * transformed_p
      result[i].pitch = math.floor(transformed_r) + 8 -- back to 0-23 range
      result[i].pitch = math.max(0, math.min(23, result[i].pitch)) -- clamp
    end
    
  elseif params.type == Transforms.VELOCITY_MOD then
    -- Velocity mod: power function transformation
    for i = 1, pattern_length do
      if result[i].current_gate == 1 then
        local v = result[i].velocity
        local p = (v - 63.5) / 64 -- scaled relative velocity
        
        local transformed_p
        if p > 0 then
          transformed_p = math.pow(p, params.g)
        elseif p < 0 then
          transformed_p = -1 * math.pow(-p, params.g)
        else
          transformed_p = 0
        end
        
        local transformed_v = 63.5 + 64 * transformed_p
        result[i].velocity = math.floor(transformed_v)
        result[i].velocity = math.max(1, math.min(127, result[i].velocity)) -- clamp 1-127
      end
    end
    
  elseif params.type == Transforms.MUTATE then
    -- Mutate: apply pitch shifts with bounce, velocity shifts with wrap
    for i = 1, pattern_length do
      -- Pitch shift with bounce
      local pitch_shift = params.pitch_shifts[i]
      local new_pitch = result[i].pitch + pitch_shift
      
      -- Bounce off limits
      if new_pitch > 23 then
        new_pitch = result[i].pitch - 1 -- Would go over, go down instead
      elseif new_pitch < 0 then
        new_pitch = result[i].pitch + 1 -- Would go under, go up instead
      end
      result[i].pitch = math.max(0, math.min(23, new_pitch))
      
      -- Velocity shift with wrap
      if result[i].current_gate == 1 then
        local velocity_shift = params.velocity_shifts[i]
        local new_velocity = result[i].velocity + velocity_shift
        -- Wrap around 1-127 range (avoid 0)
        if new_velocity > 127 then
          new_velocity = 1 + ((new_velocity - 1) % 127)
        elseif new_velocity < 1 then
          new_velocity = 127 - ((1 - new_velocity) % 127)
        end
        result[i].velocity = new_velocity
      end
    end
    
  elseif params.type == Transforms.GATE_CHAOS then
    -- Gate chaos: flip gates, create notes
    for i = 1, pattern_length do
      if params.affected_steps[i] then
        if result[i].current_gate == 1 then
          -- Mute
          result[i].current_gate = 0
        elseif result[i].original_gate == 1 then
          -- Unmute
          result[i].current_gate = 1
        else
          -- Create new note
          result[i].pitch = params.new_pitches[i]
          result[i].velocity = params.new_velocities[i]
          result[i].current_gate = 1
        end
      end
    end
    
  elseif params.type == Transforms.TIME_SHIFT then
    -- Time shift: rotate forward or reverse
    if params.shift == 0 then
      -- No change
      return result
    elseif params.reverse then
      -- Reverse the sequence
      local reversed = {}
      for i = 1, pattern_length do
        reversed[i] = {
          pitch = result[pattern_length - i + 1].pitch,
          velocity = result[pattern_length - i + 1].velocity,
          original_gate = result[pattern_length - i + 1].original_gate,
          current_gate = result[pattern_length - i + 1].current_gate
        }
      end
      result = reversed
    else
      -- Rotate forward (right shift)
      local shifted = {}
      for i = 1, pattern_length do
        local new_index = ((i - 1 + params.shift) % pattern_length) + 1
        shifted[new_index] = {
          pitch = result[i].pitch,
          velocity = result[i].velocity,
          original_gate = result[i].original_gate,
          current_gate = result[i].current_gate
        }
      end
      result = shifted
    end
  end
  
  return result
end

-- Apply transformation B (right branch) - swap r1/r2 or negate shifts
function Transforms.apply_b(sequence, params, pattern_length)
  local result = {}
  
  for i = 1, pattern_length do
    result[i] = {
      pitch = sequence[i].pitch,
      velocity = sequence[i].velocity,
      original_gate = sequence[i].original_gate,
      current_gate = sequence[i].current_gate
    }
  end
  
  if params.type == Transforms.PITCH_MOD then
    -- Pitch mod with reciprocal exponent (1/g)
    for i = 1, pattern_length do
      local pitch = result[i].pitch
      local r = pitch - 8 -- relative to base (-8 to 15)
      local p = (r - 3.5) / 12 -- scaled relative pitch
      
      local transformed_p
      local g_inv = 1.0 / params.g -- reciprocal
      if p > 0 then
        transformed_p = math.pow(p, g_inv)
      elseif p < 0 then
        transformed_p = -1 * math.pow(-p, g_inv)
      else
        transformed_p = 0
      end
      
      local transformed_r = 3.5 + 12 * transformed_p
      result[i].pitch = math.floor(transformed_r) + 8 -- back to 0-23 range
      result[i].pitch = math.max(0, math.min(23, result[i].pitch)) -- clamp
    end
    
  elseif params.type == Transforms.VELOCITY_MOD then
    -- Velocity mod with reciprocal exponent (1/g)
    for i = 1, pattern_length do
      if result[i].current_gate == 1 then
        local v = result[i].velocity
        local p = (v - 63.5) / 64 -- scaled relative velocity
        
        local transformed_p
        local g_inv = 1.0 / params.g -- reciprocal
        if p > 0 then
          transformed_p = math.pow(p, g_inv)
        elseif p < 0 then
          transformed_p = -1 * math.pow(-p, g_inv)
        else
          transformed_p = 0
        end
        
        local transformed_v = 63.5 + 64 * transformed_p
        result[i].velocity = math.floor(transformed_v)
        result[i].velocity = math.max(1, math.min(127, result[i].velocity)) -- clamp 1-127
      end
    end
    
  elseif params.type == Transforms.MUTATE then
    -- Mutate with negated shifts: pitch bounces, velocity wraps
    for i = 1, pattern_length do
      -- Pitch shift with bounce (negated)
      local pitch_shift = -params.pitch_shifts[i]
      local new_pitch = result[i].pitch + pitch_shift
      
      -- Bounce off limits
      if new_pitch > 23 then
        new_pitch = result[i].pitch - 1
      elseif new_pitch < 0 then
        new_pitch = result[i].pitch + 1
      end
      result[i].pitch = math.max(0, math.min(23, new_pitch))
      
      -- Velocity shift with wrap (negated)
      if result[i].current_gate == 1 then
        local velocity_shift = -params.velocity_shifts[i]
        local new_velocity = result[i].velocity + velocity_shift
        -- Wrap around 1-127 range (avoid 0)
        if new_velocity > 127 then
          new_velocity = 1 + ((new_velocity - 1) % 127)
        elseif new_velocity < 1 then
          new_velocity = 127 - ((1 - new_velocity) % 127)
        end
        result[i].velocity = new_velocity
      end
    end
    
  elseif params.type == Transforms.GATE_CHAOS then
    -- Gate chaos: same logic, same affected steps
    for i = 1, pattern_length do
      if params.affected_steps[i] then
        if result[i].current_gate == 1 then
          result[i].current_gate = 0
        elseif result[i].original_gate == 1 then
          result[i].current_gate = 1
        else
          result[i].pitch = params.new_pitches[i]
          result[i].velocity = params.new_velocities[i]
          result[i].current_gate = 1
        end
      end
    end
    
  elseif params.type == Transforms.TIME_SHIFT then
    -- Time shift: rotate backward or reverse (same as A)
    if params.shift == 0 then
      -- No change
      return result
    elseif params.reverse then
      -- Reverse the sequence (same as branch A - reverse is its own inverse)
      local reversed = {}
      for i = 1, pattern_length do
        reversed[i] = {
          pitch = result[pattern_length - i + 1].pitch,
          velocity = result[pattern_length - i + 1].velocity,
          original_gate = result[pattern_length - i + 1].original_gate,
          current_gate = result[pattern_length - i + 1].current_gate
        }
      end
      result = reversed
    else
      -- Rotate backward (left shift - opposite of A)
      local shifted = {}
      for i = 1, pattern_length do
        local new_index = ((i - 1 - params.shift) % pattern_length) + 1
        shifted[new_index] = {
          pitch = result[i].pitch,
          velocity = result[i].velocity,
          original_gate = result[i].original_gate,
          current_gate = result[i].current_gate
        }
      end
      result = shifted
    end
  end
  
  return result
end

return Transforms
