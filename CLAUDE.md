# CLAUDE.md - Project Context for AI Assistants

## Project Overview

**Thorns** is a Fractal MIDI Sequencer for the norns hardware platform. Users create a short musical pattern (the "trunk"), and the system generates a binary transformation tree with 7 levels of depth. Players navigate this tree in real-time using encoders, hearing variations of the pattern generated through mathematical transformations.

## Tech Stack

- **Language**: Lua 5.1+
- **Platform**: norns (open-source music synthesis hardware)
- **Dependencies**:
  - `nb` library (nota bene) - Git submodule at `lib/nb`
  - Built-in norns libraries: `musicutil`, `grid`, `clock`, `midi`, `params`

## Project Structure

```
thorns/
├── thorns.lua           # Main entry point (orchestration, input, state)
├── lib/
│   ├── tree.lua         # Binary tree generation and navigation
│   ├── transforms.lua   # 5 transformation algorithms
│   ├── grid_display.lua # Grid visualization and editing UI
│   └── nb/              # Git submodule - nota bene synth library
├── README.md            # User documentation
└── NB_INTEGRATION.md    # nb library integration docs
```

## Key Files

| File | Purpose |
|------|---------|
| `thorns.lua` | Main controller: init, input handling, playback, screen rendering |
| `lib/tree.lua` | Generates 7-level binary tree, retrieves sequences by level/path |
| `lib/transforms.lua` | Implements PITCH_MOD, VELOCITY_MOD, MUTATE, GATE_CHAOS, TIME_SHIFT |
| `lib/grid_display.lua` | Grid UI with Gate/Pitch and Velocity screens |

## Build & Setup

No compilation needed - pure Lua scripts for norns.

```bash
# Initialize git submodule (pulls nb library)
git submodule update --init --recursive
```

## Key Data Structures

```lua
-- trunk: User-editable pattern (16 steps)
trunk = {
  {pitch = 60, velocity = 100, gate = true},
  ...
}

-- tree: Generated transformation tree
tree = {
  depth = 7,
  nodes = {
    [0] = {trunk},           -- Level 0: 1 sequence
    [1] = {seq_a, seq_b},    -- Level 1: 2 sequences
    [2] = {...},             -- Level 2: 4 sequences
    ...                      -- Up to 128 sequences at level 7
  }
}
```

## Coding Conventions

- **Variables/functions**: snake_case (`pattern_length`, `current_step`)
- **Modules**: CamelCase (`GridDisplay`, `Transforms`)
- **Constants**: UPPER_CASE (`Transforms.PITCH_MOD`)
- **Module pattern**: Each library returns a table with functions
- **Imports**: Use `include()` for relative imports

## Architecture Notes

- Tree is always generated at max depth (7 levels) when trunk is modified
- All random values pre-generated at tree construction (deterministic playback)
- Binary decomposition for tree navigation: `branch_index = floor(path * 2^level) + 1`
- Screen updates throttled to 15 FPS via metro
- Step timing driven by norns clock (sample-accurate)

## Transformation Types

1. **PITCH_MOD**: Nonlinear pitch transformation using power functions
2. **VELOCITY_MOD**: Dynamic range expansion/compression
3. **MUTATE**: Step-by-step pitch/velocity shifts (±1 semitone, ±8 velocity)
4. **GATE_CHAOS**: Stochastic note activation/muting
5. **TIME_SHIFT**: Pattern rotation and reversal

## Hardware Controls

- **E1**: Branches (0-7) | K1+E1: Octave shift
- **E2**: Path (0.0-0.99) | K1+E2: Pattern length (edit mode)
- **E3**: Tempo (20-300 BPM)
- **K2**: Play/Stop toggle
- **K3**: Toggle edit screens (edit mode only)
- **Grid**: Note editing (edit mode) or visualization (play mode)

## License

GNU General Public License v3
