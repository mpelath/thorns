-- Tree
-- Binary transformation tree generator for Thorns

local Transforms = include('thorns/lib/transforms')

local Tree = {}

function Tree.init(trunk)
  -- Nothing to init
end

-- Generate complete transformation tree
function Tree.generate(trunk, pattern_length, max_depth, gate_chaos_prob, mutation_prob, shift_freedom, enabled_transforms)
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
  
  -- If no transformations are enabled, just return trunk
  if #enabled_transforms == 0 then
    print("Warning: No transformations enabled")
    tree.depth = 0
    return tree
  end
  
  -- Generate each level
  for level = 1, max_depth do
    tree.nodes[level] = {}
    local prev_level = tree.nodes[level - 1]
    
    print("Generating level", level, "from", #prev_level, "parent nodes")
    
    -- Each node in previous level branches into two nodes
    for node_idx = 1, #prev_level do
      local parent_sequence = prev_level[node_idx]
      
      -- Randomly select from enabled transformation types
      local transform_type = enabled_transforms[math.random(1, #enabled_transforms)]
      
      -- Generate random parameters for this transformation
      local params = Transforms.generate_params(
        transform_type,
        pattern_length,
        gate_chaos_prob,
        mutation_prob,
        shift_freedom
      )
      
      -- Apply transformation A (left branch)
      local left_sequence = Transforms.apply_a(parent_sequence, params, pattern_length)
      
      -- Apply transformation B (right branch)
      local right_sequence = Transforms.apply_b(parent_sequence, params, pattern_length)
      
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
