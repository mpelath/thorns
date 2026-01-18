-- Thorns
-- Fractal sequencer
-- 
-- Grid required
--
-- E1: Branches (0-7)
-- E2: Path (0.0-1.0)
-- E3: Tempo
-- K2: Play/Stop
-- K3: Screen toggle (edit)
-- K1+E1: Octave shift
-- K1+E2: Pattern length

local nb = require 'nb/lib/nb'
local g = grid.connect()
local musicutil = require('musicutil')

local voice_player -- nb voice player

-- Modules
local Tree = include('thorns/lib/tree')
local GridDisplay = include('thorns/lib/grid_display')
local Transforms = include('thorns/lib/transforms')

-- State
local playing = false
local trunk_dirty = true
local current_level = 0
local current_step = 1
local edit_screen = 1 -- 1 = gate/pitch, 2 = velocity
local octave_offset = 1 -- 0, 1, or 2 (viewing windows)
local k1_held = false

-- Trunk (user-editable pattern)
local trunk = {}
local pattern_length = 16

-- Tree
local tree = nil

-- Playback
local step_clock = nil
local step_position = 0
local current_sequence = nil

-- Display
local screen_dirty = true
local screen_refresh = nil

-- Parameters
local branches = 0
local path = 0.0
local tempo = 120
local scale = nil

function init()
  -- Initialize nb voice library
  nb:init()
  
  -- Initialize trunk
  for i = 1, 16 do
    trunk[i] = {
      pitch = 0,
      velocity = 64,
      original_gate = 0,
      current_gate = 0
    }
  end
  
  -- Setup parameters
  setup_params()
  
  -- Initialize scale and base pitch
  update_scale(1) -- Major scale by default
  GridDisplay.set_base_pitch(params:get("base_pitch"))
  
  -- Initialize modules
  Tree.init(trunk)
  GridDisplay.init(g, trunk)
  
  -- Grid callbacks
  g.key = function(x, y, z)
    grid_key(x, y, z)
  end
  
  -- Start screen refresh
  screen_refresh = metro.init()
  screen_refresh.time = 1/15
  screen_refresh.event = function()
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
  screen_refresh:start()
  
  screen_dirty = true
end

function setup_params()
  params:add_separator("Thorns")
  
  -- Add nb voice selector
  nb:add_param("voice", "Voice")
  nb:add_player_params()
  
  -- Output
  params:add{
    type = "option",
    id = "output_mode",
    name = "Output Mode",
    options = {"Audio", "MIDI", "Both"},
    default = 1
  }
  
  -- MIDI
  params:add{
    type = "number",
    id = "midi_channel",
    name = "MIDI Channel",
    min = 1, max = 16,
    default = 1
  }
  
  params:add{
    type = "option",
    id = "midi_device",
    name = "MIDI Device",
    options = {"Virtual", "Device 1", "Device 2", "Device 3", "Device 4"},
    default = 1,
    action = function(value)
      midi_out = midi.connect(value)
    end
  }
  
  -- Pitch/Scale
  params:add{
    type = "number",
    id = "base_pitch",
    name = "Base Pitch",
    min = 24, max = 72,
    default = 60, -- Middle C
    formatter = function(param)
      return musicutil.note_num_to_name(param:get(), true)
    end,
    action = function(value)
      GridDisplay.set_base_pitch(value)
    end
  }
  
  params:add{
    type = "option",
    id = "scale",
    name = "Scale",
    options = {"Major", "Minor", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Aeolian", "Locrian", "Chromatic"},
    default = 1,
    action = function(value)
      update_scale(value)
    end
  }
  
  -- Transformation probabilities
  params:add_separator("Transformations")
  
  params:add{
    type = "control",
    id = "pitch_mod_prob",
    name = "Pitch Mod Prob",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5),
  }
  
  params:add{
    type = "control",
    id = "velocity_mod_prob",
    name = "Velocity Mod Prob",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5),
  }
  
  params:add{
    type = "control",
    id = "gate_chaos_prob",
    name = "Gate Chaos Prob",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.05),
  }
  
  params:add{
    type = "control",
    id = "mutation_prob",
    name = "Mutation Prob",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5),
  }
  
  params:add{
    type = "control",
    id = "shift_freedom",
    name = "Shift Freedom",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5),
  }
  
  -- Clock
  params:add{
    type = "option",
    id = "clock_source",
    name = "Clock Source",
    options = {"Internal"},
    default = 1
  }
  
  -- Add PolyPerc engine params
  -- Initialize MIDI from parameter
  midi_out = midi.connect(params:get("midi_device"))
  
  -- Get nb voice player
  voice_player = params:lookup_param("voice"):get_player()
end

function update_scale(scale_id)
  local scale_names = {
    {0, 2, 4, 5, 7, 9, 11}, -- Major
    {0, 2, 3, 5, 7, 8, 10}, -- Minor
    {0, 2, 3, 5, 7, 9, 10}, -- Dorian
    {0, 1, 3, 5, 7, 8, 10}, -- Phrygian
    {0, 2, 4, 6, 7, 9, 11}, -- Lydian
    {0, 2, 4, 5, 7, 9, 10}, -- Mixolydian
    {0, 2, 3, 5, 7, 8, 10}, -- Aeolian
    {0, 1, 3, 5, 6, 8, 10}, -- Locrian
    {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11} -- Chromatic
  }
  
  scale = scale_names[scale_id]
  GridDisplay.set_scale(scale)
end

function key(n, z)
  if n == 1 then
    k1_held = (z == 1)
  end
  
  if z == 1 then
    if n == 2 then
      -- Play/Stop
      toggle_playback()
    elseif n == 3 and not playing then
      -- Toggle screen (edit mode only)
      edit_screen = edit_screen == 1 and 2 or 1
      GridDisplay.set_screen(edit_screen)
      screen_dirty = true
    end
  end
end

function enc(n, d)
  if n == 1 then
    if k1_held then
      -- K1+E1: Octave shift (anytime)
      octave_offset = util.clamp(octave_offset + d, 0, 2)
      GridDisplay.set_octave(octave_offset)
      screen_dirty = true
    else
      -- E1: Branches (anytime - controls playback depth)
      branches = util.clamp(branches + d, 0, 7)
      screen_dirty = true
    end
  elseif n == 2 then
    if k1_held then
      -- K1+E2: Pattern length
      if not playing then
        pattern_length = util.clamp(pattern_length + d, 2, 16)
        GridDisplay.set_length(pattern_length)
        trunk_dirty = true
        screen_dirty = true
      end
    else
      -- E2: Path
      path = util.clamp(path + d * 0.01, 0.0, 0.99)
      screen_dirty = true
    end
  elseif n == 3 then
    -- E3: Tempo
    tempo = util.clamp(tempo + d, 20, 300)
    screen_dirty = true
  end
end

function grid_key(x, y, z)
  if not playing and z == 1 then
    -- Edit mode only
    local step = x
    local pitch_row = y
    
    if step <= pattern_length then
      if edit_screen == 1 then
        -- Gate/pitch screen
        local pitch = (octave_offset * 8) + (8 - pitch_row)
        GridDisplay.edit_note(step, pitch)
        trunk_dirty = true
      else
        -- Velocity screen
        local velocity = math.floor((9 - pitch_row) * 127 / 8)
        velocity = math.max(1, math.min(127, velocity))
        trunk[step].velocity = velocity
        trunk_dirty = true
      end
      
      GridDisplay.update()
    end
  end
end

function toggle_playback()
  if playing then
    stop_playback()
  else
    start_playback()
  end
end

function start_playback()
  -- Generate tree if trunk changed
  if trunk_dirty then
    print("Generating tree...")
    
    local max_depth = 7
    tree = Tree.generate(
      trunk,
      pattern_length,
      max_depth,
      params:get("gate_chaos_prob"),
      params:get("mutation_prob"),
      params:get("shift_freedom"),
      params:get("pitch_mod_prob"),
      params:get("velocity_mod_prob")
    )
    print("Tree generated with max depth:", max_depth)
    print("Pattern length:", pattern_length)
    trunk_dirty = false
  end
  
  playing = true
  current_level = 0
  step_position = 0
  
  -- Start step clock
  step_clock = clock.run(function()
    while playing do
      clock.sleep(60 / tempo / 4) -- 16th notes based on tempo
      step()
    end
  end)
  
  GridDisplay.set_playing(true)
  screen_dirty = true
end

function stop_playback()
  playing = false
  
  if step_clock then
    clock.cancel(step_clock)
    step_clock = nil
  end
  
  -- Send MIDI all notes off
  for i = 1, 128 do
    midi_out:note_off(i, 0, params:get("midi_channel"))
  end
  
  GridDisplay.set_playing(false)
  screen_dirty = true
end

function step()
  step_position = step_position + 1
  print("Step:", step_position, "Level:", current_level)
  
  -- Get current sequence from tree
  current_sequence = Tree.get_sequence(tree, current_level, path, branches)
  local note_index = ((step_position - 1) % pattern_length) + 1
  
  -- Check if we've completed this level
  if step_position > pattern_length then
    step_position = 1
    current_level = current_level + 1
    
    -- Loop back to trunk after completing all levels
    if current_level > branches then
      current_level = 0
    end
    
    -- Get sequence for new level
    current_sequence = Tree.get_sequence(tree, current_level, path, branches)
  end
  
  -- Play note
  local note = current_sequence[note_index]
  if note and note.current_gate == 1 then
    -- Quantize to scale
    local base = params:get("base_pitch")
    local pitch_offset = note.pitch - 8
    local midi_note = quantize_to_scale(base + pitch_offset)
    
    local output_mode = params:get("output_mode")
    
    -- Audio engine output via nb
    if output_mode == 1 or output_mode == 3 then
      local vel = note.velocity / 127.0
      -- Note duration: 90% of a 16th note (1/4 beat)
      voice_player:play_note(midi_note, vel, 0.9 * 1/4)
    end
    
    -- MIDI output
    if output_mode == 2 or output_mode == 3 then
      midi_out:note_on(midi_note, note.velocity, params:get("midi_channel"))
      
      -- Note off on next step
      clock.run(function()
        clock.sync(1/4 * 0.9)
        midi_out:note_off(midi_note, 0, params:get("midi_channel"))
      end)
    end
  end
  
  -- Update display
  GridDisplay.set_step(note_index, current_level)
  GridDisplay.set_current_sequence(current_sequence)
  screen_dirty = true
end

function quantize_to_scale(midi_note)
  if not scale then
    return midi_note
  end
  
  local octave = math.floor(midi_note / 12)
  local note_in_octave = midi_note % 12
  
  -- Find nearest scale degree
  local min_distance = 12
  local closest = note_in_octave
  
  for _, scale_note in ipairs(scale) do
    local distance = math.abs(note_in_octave - scale_note)
    if distance < min_distance then
      min_distance = distance
      closest = scale_note
    end
  end
  
  return octave * 12 + closest
end

function redraw()
  screen.clear()
  
  if playing then
    -- Play mode display
    screen.level(15)
    screen.move(0, 10)
    screen.text("PLAYING (K2 to stop)")
    
    screen.level(4)
    screen.move(0, 25)
    screen.text("E1: Branches: " .. branches .. " (Lvl " .. current_level .. ")")
    
    screen.move(0, 35)
    screen.text("E2: Path: " .. string.format("%.2f", path))
    
    screen.move(0, 45)
    screen.text("E3: Tempo: " .. tempo)
    
    screen.move(0, 55)
    screen.text("K1+E1: Octave: " .. (octave_offset + 1))
    
  else
    -- Edit mode display
    screen.level(15)
    screen.move(0, 10)
    screen.text("EDIT (K2 to play)")
    
    screen.level(4)
    screen.move(0, 25)
    screen.text("E1: Branches: " .. branches)
    
    screen.move(0, 35)
    screen.text("K1+E1: Octave: " .. (octave_offset + 1))
    
    screen.move(0, 45)
    screen.text("K1+E2: Length: " .. pattern_length)
    
    screen.move(0, 55)
    screen.text("K3: " .. (edit_screen == 1 and "Gate/Pitch" or "Velocity"))
  end
  
  screen.update()
end

function cleanup()
  if playing then
    stop_playback()
  end
end
