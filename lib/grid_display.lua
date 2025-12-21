-- Grid Display
-- Grid visualization and editing for Thorns

local GridDisplay = {}

local g = nil
local trunk = nil
local pattern_length = 16
local current_screen = 1 -- 1 = gate/pitch, 2 = velocity
local octave_offset = 1 -- 0, 1, or 2
local scale = nil
local playing = false
local current_step = 1
local current_level = 0
local current_sequence = nil
local base_pitch = 60

function GridDisplay.init(grid, trunk_ref)
  g = grid
  trunk = trunk_ref
  GridDisplay.update()
end

function GridDisplay.set_length(length)
  pattern_length = length
  GridDisplay.update()
end

function GridDisplay.set_screen(screen)
  current_screen = screen
  GridDisplay.update()
end

function GridDisplay.set_octave(offset)
  octave_offset = offset
  GridDisplay.update()
end

function GridDisplay.set_scale(scale_degrees)
  scale = scale_degrees
  GridDisplay.update()
end

function GridDisplay.set_base_pitch(pitch)
  base_pitch = pitch
  GridDisplay.update()
end

function GridDisplay.set_playing(is_playing)
  playing = is_playing
  GridDisplay.update()
end

function GridDisplay.set_step(step, level)
  current_step = step
  current_level = level
  GridDisplay.update()
end

function GridDisplay.set_current_sequence(sequence)
  current_sequence = sequence
end

function GridDisplay.edit_note(step, pitch)
  -- Toggle gate if clicking same pitch, otherwise set new note
  if trunk[step].current_gate == 1 and trunk[step].pitch == pitch then
    -- Clear gate
    trunk[step].current_gate = 0
    trunk[step].original_gate = 0
  else
    -- Set note
    trunk[step].pitch = pitch
    trunk[step].current_gate = 1
    trunk[step].original_gate = 1
  end
end

function GridDisplay.update()
  if not g then return end
  
  g:all(0)
  
  if not playing then
    -- Edit mode
    if current_screen == 1 then
      GridDisplay.draw_gate_pitch()
    else
      GridDisplay.draw_velocity()
    end
  else
    -- Play mode
    GridDisplay.draw_playback()
  end
  
  g:refresh()
end

function GridDisplay.draw_gate_pitch()
  -- Draw scale degrees dimly
  if scale and base_pitch then
    for col = 1, pattern_length do
      for row = 1, 8 do
        local pitch = (octave_offset * 8) + (8 - row)
        -- Calculate actual MIDI note for this pitch
        local midi_note = base_pitch + (pitch - 8) -- pitch 8 = base note
        local pitch_in_octave = midi_note % 12
        
        -- Check if this pitch class is in the scale
        for _, scale_note in ipairs(scale) do
          if pitch_in_octave == scale_note then
            g:led(col, row, 2) -- Dim
            break
          end
        end
      end
    end
  end
  
  -- Draw active notes
  for col = 1, pattern_length do
    if trunk[col].current_gate == 1 then
      local pitch = trunk[col].pitch
      local row = 8 - (pitch - octave_offset * 8)
      
      if row >= 1 and row <= 8 then
        local brightness = (col == current_step and playing) and 15 or 10
        g:led(col, row, brightness)
      end
    end
  end
end

function GridDisplay.draw_velocity()
  for col = 1, pattern_length do
    if trunk[col].current_gate == 1 then
      local velocity = trunk[col].velocity
      local height = math.ceil(velocity * 8 / 127)
      
      for row = 1, height do
        local brightness = (col == current_step and playing) and 15 or 10
        g:led(col, 9 - row, brightness)
      end
    end
  end
end

function GridDisplay.draw_playback()
  if not current_sequence then return end
  
  -- Show transformed sequence
  for col = 1, pattern_length do
    if current_sequence[col] and current_sequence[col].current_gate == 1 then
      local pitch = current_sequence[col].pitch
      
      -- Determine which octave window this pitch falls into
      local window = math.floor(pitch / 8)
      
      if window == octave_offset then
        local row = 8 - (pitch - octave_offset * 8)
        if row >= 1 and row <= 8 then
          local brightness = (col == current_step) and 15 or 8
          g:led(col, row, brightness)
        end
      end
    end
  end
  
  -- Highlight current step column dimly where no notes
  if current_step > 0 and current_step <= 16 then
    for row = 1, 8 do
      -- Only light if not already lit by a note
      local has_note = false
      if current_sequence[current_step] and current_sequence[current_step].current_gate == 1 then
        local pitch = current_sequence[current_step].pitch
        local window = math.floor(pitch / 8)
        if window == octave_offset then
          local note_row = 8 - (pitch - octave_offset * 8)
          if row == note_row then
            has_note = true
          end
        end
      end
      
      if not has_note then
        g:led(current_step, row, 2)
      end
    end
  end
end

return GridDisplay
