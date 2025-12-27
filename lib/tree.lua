-- Tree
-- Binary transformation tree generator for Thorns

local Transforms = include('thorns/lib/transforms')

local Tree = {}

function Tree.init(trunk)
  -- Nothing to init
end

-- Generate complete transformation tree
function Tree.generate(trunk, pattern_length, max_depth, gate_chaos_prob, mutation_prob, shift_freedom, pitch_mod_prob, velocity_mod_prob, time_shift_prob)
  -- Build tree structure
  local tree = {
    depth = max_depth,
    nodes = {}
  }
  
  -- Level 0 is the trunk
  tree.nodes[0] = {trunk}
  
  if max_depth == 0 then
    -- No transformations, just return trunk
    return treea
  end
  
  -- Generate each level
  for level = 1, max_depth do
    tree.nodes[level] = {}
    local prev_level = tree.nodes[level - 1]
    
    print("Generating level", level, "from", #prev_level, "parent nodes")
    
    -- Each node in previous level branches into two nodes
    for node_idx = 1, #prev_level do
      local parent_sequence = prev_level[node_idx]
      
      -- Determine which transformations to apply based on probabilities
      local apply_time_shift = (math.random() < time_shift_prob)
      local apply_pitch_mod = (math.random() < pitch_mod_prob)
      local apply_velocity_mod = (math.random() < velocity_mod_prob)
      -- Gate chaos and mutate always apply, but use per-step probabilities
      
      -- Generate params for each transformation that will be applied
      local params_list = {}
      
      if apply_time_shift then
        table.insert(params_list, Transforms.generate_params(
          Transforms.TIME_SHIFT,
          pattern_length,
          gate_chaos_prob,
          mutation_prob,
          shift_freedom
        ))
      end
      
      if apply_pitch_mod then
        table.insert(params_list, Transforms.generate_params(
          Transforms.PITCH_MOD,
          pattern_length,
          gate_chaos_prob,
          mutation_prob,
          shift_freedom
        ))
      end
      
      if apply_velocity_mod then
        table.insert(params_list, Transforms.generate_params(
          Transforms.VELOCITY_MOD,
          pattern_length,
          gate_chaos_prob,
          mutation_prob,
          shift_freedom
        ))
      end
      
      -- Always generate params for gate chaos and mutate
      table.insert(params_list, Transforms.generate_params(
        Transforms.GATE_CHAOS,
        pattern_length,
        gate_chaos_prob,
        mutation_prob,
        shift_freedom
      ))
      
      table.insert(params_list, Transforms.generate_params(
        Transforms.MUTATE,
        pattern_length,
        gate_chaos_prob,
        mutation_prob,
        shift_freedom
      ))
      
      -- Apply all transformations in sequence for branch A (left)
      local left_sequence = parent_sequence
      for _, params in ipairs(params_list) do
        left_sequence = Transforms.apply_a(left_sequence, params, pattern_length)
      end
      
      -- Apply all transformations in sequence for branch B (right)
      local right_sequence = parent_sequence
      for _, params in ipairs(params_list) do
        right_sequence = Transforms.apply_b(right_sequence, params, pattern_length)
      end
      
      -- Store both branches
      table.insert(tree.nodes[level], left_sequence)
      table.insert(tree.nodes[level], right_sequence)
    end
    
    print("Level", level, "has", #tree.nodes[level], "nodes")
  end
  
  return tree
end

-- Get sequence at specific level and path
function Tree.get_sequence(tree, level, path, max_depth)
  if not tree then
    print("ERROR: tree is nil")
    return nil
  end
  
  -- Clamp level
  level = math.max(0, math.min(max_depth, level))
  
  if level == 0 then
    -- Return trunk
    return tree.nodes[0][1]
  end
  
  -- Calculate which branch to follow using binary decomposition
  -- Path 0.0-1.0 maps to 2^level branches
  local num_branches = math.pow(2, level)
  local branch_index = math.floor(path * num_branches) + 1
  
  -- Clamp to valid range
  branch_index = math.max(1, math.min(num_branches, branch_index))
  
  print("Getting level", level, "branch", branch_index, "of", num_branches)
  print("tree.nodes[" .. level .. "] exists:", tree.nodes[level] ~= nil)
  if tree.nodes[level] then
    print("tree.nodes[" .. level .. "] has", #tree.nodes[level], "entries")
  end
  
  return tree.nodes[level][branch_index]
end

return Tree-- Tree
-- Binary transformation tree generator for Thorns

local Transforms = include('thorns/lib/transforms')

local Tree = {}

function Tree.init(trunk)
  -- Nothing to init
end

-- Generate complete transformation tree
function Tree.generate(trunk, pattern_length, max_depth, gate_chaos_prob, mutation_prob, shift_freedom, pitch_mod_prob, velocity_mod_prob, time_shift_prob)
  -- Build tree structure
  local tree = {
    depth = max_depth,
    nodes = {}
  }
  
  -- Level 0 is the trunk
  tree.nodes[0] = {trunk}
  
  if max_depth == 0 then
    -- No transformations, just return trunk
    return treea
  end
  
  -- Generate each level
  for level = 1, max_depth do
    tree.nodes[level] = {}
    local prev_level = tree.nodes[level - 1]
    
    print("Generating level", level, "from", #prev_level, "parent nodes")
    
    -- Each node in previous level branches into two nodes
    for node_idx = 1, #prev_level do
      local parent_sequence = prev_level[node_idx]
      
      -- Determine which transformations to apply based on probabilities
      local apply_time_shift = (math.random() < time_shift_prob)
      local apply_pitch_mod = (math.random() < pitch_mod_prob)
      local apply_velocity_mod = (math.random() < velocity_mod_prob)
      -- Gate chaos and mutate always apply, but use per-step probabilities
      
      -- Generate params for each transformation that will be applied
      local params_list = {}
      
      if apply_time_shift then
        table.insert(params_list, Transforms.generate_params(
          Transforms.TIME_SHIFT,
          pattern_length,
          gate_chaos_prob,
          mutation_prob,
          shift_freedom
        ))
      end
      
      if apply_pitch_mod then
        table.insert(params_list, Transforms.generate_params(
          Transforms.PITCH_MOD,
          pattern_length,
          gate_chaos_prob,
          mutation_prob,
          shift_freedom
        ))
      end
      
      if apply_velocity_mod then
        table.insert(params_list, Transforms.generate_params(
          Transforms.VELOCITY_MOD,
          pattern_length,
          gate_chaos_prob,
          mutation_prob,
          shift_freedom
        ))
      end
      
      -- Always generate params for gate chaos and mutate
      table.insert(params_list, Transforms.generate_params(
        Transforms.GATE_CHAOS,
        pattern_length,
        gate_chaos_prob,
        mutation_prob,
        shift_freedom
      ))
      
      table.insert(params_list, Transforms.generate_params(
        Transforms.MUTATE,
        pattern_length,
        gate_chaos_prob,
        mutation_prob,
        shift_freedom
      ))
      
      -- Apply all transformations in sequence for branch A (left)
      local left_sequence = parent_sequence
      for _, params in ipairs(params_list) do
        left_sequence = Transforms.apply_a(left_sequence, params, pattern_length)
      end
      
      -- Apply all transformations in sequence for branch B (right)
      local right_sequence = parent_sequence
      for _, params in ipairs(params_list) do
        right_sequence = Transforms.apply_b(right_sequence, params, pattern_length)
      end
      
      -- Store both branches
      table.insert(tree.nodes[level], left_sequence)
      table.insert(tree.nodes[level], right_sequence)
    end
    
    print("Level", level, "has", #tree.nodes[level], "nodes")
  end
  
  return tree
end

-- Get sequence at specific level and path
function Tree.get_sequence(tree, level, path, max_depth)
  if not tree then
    print("ERROR: tree is nil")
    return nil
  end
  
  -- Clamp level
  level = math.max(0, math.min(max_depth, level))
  
  if level == 0 then
    -- Return trunk
    return tree.nodes[0][1]
  end
  
  -- Calculate which branch to follow using binary decomposition
  -- Path 0.0-1.0 maps to 2^level branches
  local num_branches = math.pow(2, level)
  local branch_index = math.floor(path * num_branches) + 1
  
  -- Clamp to valid range
  branch_index = math.max(1, math.min(num_branches, branch_index))
  
  print("Getting level", level, "branch", branch_index, "of", num_branches)
  print("tree.nodes[" .. level .. "] exists:", tree.nodes[level] ~= nil)
  if tree.nodes[level] then
    print("tree.nodes[" .. level .. "] has", #tree.nodes[level], "entries")
  end
  
  return tree.nodes[level][branch_index]
end

return Tree
