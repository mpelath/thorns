-- Tree
-- Binary transformation tree generator for Thorns

local Transforms = include('thorns/lib/transforms')

local Tree = {}

function Tree.init(trunk)
  -- Nothing to init
end

-- Generate complete transformation tree
function Tree.generate(trunk, pattern_length, max_depth, gate_chaos_prob, mutation_prob, shift_freedom, pitch_mod_prob, velocity_mod_prob)
  -- Build tree structure
  local tree = {
    depth = max_depth,
    nodes = {}
  }
  
  -- Level 0 is the trunk
  tree.nodes[0] = {trunk}
  
  if max_depth == 0 then
    -- No transformations, just return trunk
    return tree
  end
  
  -- Generate each level
  for level = 1, max_depth do
    tree.nodes[level] = {}
    local prev_level = tree.nodes[level - 1]
    
    -- Each node in previous level branches into two nodes
    for node_idx = 1, #prev_level do
      local parent_sequence = prev_level[node_idx]
      
      -- Determine which transformations to apply based on probabilities
      local apply_pitch_mod = (math.random() < pitch_mod_prob)
      local apply_velocity_mod = (math.random() < velocity_mod_prob)
      -- Time shift, gate chaos, and mutate always apply (time shift uses shift_freedom distribution)
      
      -- Generate params for each transformation that will be applied
      local params_list = {}
      
      -- Time shift always applied (shift_freedom controls whether it actually shifts)
      table.insert(params_list, Transforms.generate_params(
        Transforms.TIME_SHIFT,
        pattern_length,
        gate_chaos_prob,
        mutation_prob,
        shift_freedom
      ))
      
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
  end
  
  return tree
end

-- Get sequence at specific level and path
function Tree.get_sequence(tree, level, path, max_depth)
  if not tree then
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
  
  return tree.nodes[level][branch_index]
end

return Tree
