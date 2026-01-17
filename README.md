# Thorns

Fractal MIDI sequencer for norns + grid

## Requirements

- norns (any version)
- Grid (16x8 minimum)
- MIDI output device

## Features

- Monophonic step sequencer (2-16 steps)
- Binary transformation tree with 7 levels of depth
- Five transformation types:
  - Pitch modification (nonlinear power function)
  - Velocity modification (nonlinear power function)
  - Mutate (±1 semitone shifts)
  - Gate chaos (mute/unmute/create notes)
  - Time shift (rotate pattern forward/backward)
- Real-time path navigation through transformation space
- Scale quantization
- Grid-based editing with octave windows
- Separate gate/pitch and velocity editing screens
- Audio engine (PolyPerc) or MIDI output

## Controls

### Encoders
- **E1:** Branches (tree depth: 0-7) - changeable anytime
- **E2:** Path (navigate variations: 0.0-0.99) - changeable anytime
- **E3:** Tempo (20-300 BPM) - changeable anytime

### Keys
- **K2:** Play/Stop
- **K3:** Toggle gate/pitch ↔ velocity screen (edit mode only)

### Key Combinations
- **K1+E1:** Shift octave window (move visible pitch range up/down) - changeable anytime
- **K1+E2:** Change pattern length (2-16 steps) - edit mode only

### Grid

**Edit Mode (Stopped):**
- Screen 1 (Gate/Pitch): Click cells to set/clear notes
  - Columns = steps (1-16)
  - Rows = pitches (8 visible at a time from 3-octave range)
  - Scale degrees shown dimly
- Screen 2 (Velocity): Click column to set velocity height
  - Vertical bar height = velocity (8 levels)

**Play Mode:**
- Displays currently playing transformed sequence
- Current step highlighted
- Shows notes in current octave window (use K1+E1 to shift view)
- Read-only display

## Parameters Menu

- **Output Mode:** Audio / MIDI / Both (default: Audio)
- **Base Pitch:** Root note of the 3-octave range (C0-C4)
- **Scale:** Quantization scale (Major, Minor, Dorian, etc.)
- **Transformations:**
  - **Pitch Mod Prob:** Probability of applying pitch modification (0.0-1.0, default 0.5)
  - **Velocity Mod Prob:** Probability of applying velocity modification (0.0-1.0, default 0.5)
- **Gate Chaos Probability:** Chance per step for gate chaos (0.0-1.0, default 0.05)
- **Mutation Probability:** Chance per step for mutation (0.0-1.0, default 0.5)
- **Shift Freedom:** Controls time shift distribution (0.0-1.0, default 0.5)
  - 0.0: no shifting (always stays in place)
  - 1.0: all shifts equally likely (uniform distribution)
  - 0.0-1.0: favors smaller shifts
  - Note: Time shift is always applied, but shift_freedom controls its behavior
- **Audio Engine:**
  - **Release:** Note release time (0.1-5.0s, default 0.5)
  - **Cutoff:** Filter cutoff frequency (50-5000Hz, default 1000)
  - **Gain:** Output gain (0.0-4.0, default 1.0)
- **MIDI Output Channel:** 1-16
- **MIDI Device:** Virtual or hardware device
- **Clock Source:** Internal (only)

## How It Works

### Pitch Range
- 24 semitones total: 8 below base pitch to 15 above
- Displayed in 3 windows of 8 semitones each
- Input is chromatic (all 24 semitones available)
- Output is quantized to selected scale

### Transformation Tree
When you hit play with a modified trunk:
1. Generates a complete 7-level binary tree (always maximum depth)
2. At each branch level:
   - Pitch modification and velocity modification are checked against their probabilities
   - Time shift, gate chaos, and mutation are always applied (but have their own control parameters)
3. Multiple transformations can be applied to the same branch (they stack in sequence)
4. Pre-generates all random values (so playback is deterministic)
5. Stores full sequences at every node

The Branches parameter (0-7) controls how deep into the tree you play before looping back to the trunk. The tree is always generated at full depth, so you can adjust Branches in real-time during playback without regenerating.

Control parameters:
- Pitch/Velocity Mod Prob: 0.0 = never applies, 1.0 = always applies
- Shift Freedom: 0.0 = never shifts, 1.0 = all shift amounts equally likely
- Gate Chaos/Mutation Prob: per-step probabilities (even when transformation "always applies")

### Playback
- Branches parameter (0-7) determines playback depth (changeable in real-time)
- Path parameter (0.0-0.99) determines which branch to follow at each level
- Path value is decomposed into binary choices (left/right at each level)
- Playback sequence: trunk → level 1 → level 2 → ... → level N (where N = Branches) → loop
- Branches = 0 plays only the trunk
- Tree is always generated at maximum depth (7 levels), Branches just controls how deep you play

**Example:** If Branches = 2 and Path = 0.3:
- Path 0.3 falls in range [0.25, 0.375) = binary "01"
- Playback sequence: trunk → left branch → right branch → loop

### Transformations

**1. Pitch Modification**
- Nonlinear pitch transformation using power function
- For each note: r = pitch relative to base (-8 to 15), p = (r - 3.5) / 12
- Random exponent g between 1 and 2
- If p > 0: transformed_p = p^g
- If p < 0: transformed_p = -(-p)^g  
- Transform back: r = 3.5 + 12 × transformed_p
- Branch A: uses exponent g (expands high/low ranges)
- Branch B: uses exponent 1/g (compresses toward center)

**2. Velocity Modification**
- Nonlinear velocity transformation using power function
- For each note: v = velocity (0-127), p = (v - 63.5) / 64
- Random exponent g between 1 and 10
- If p > 0: transformed_p = p^g
- If p < 0: transformed_p = -(-p)^g
- Transform back: v = 63.5 + 64 × transformed_p
- Branch A: uses exponent g (expands dynamic range)
- Branch B: uses exponent 1/g (compresses toward middle velocity)

**3. Mutate**
- Randomly shifts both pitch and velocity for each step
- Pitch: shifts by -1, 0, or +1 semitone with probabilities: -1 (p/2), 0 (1-p), +1 (p/2) where p = mutation probability
- Pitch bounces off range limits (-8 to +15 semitones relative to base pitch)
- Velocity: shifts by -8, 0, or +8 units with same probability distribution
- Velocity wraps around range (1-127)
- Branch A: Apply shifts as generated
- Branch B: Apply negated shifts

**4. Gate Chaos**
- Each step has probability p (gate chaos probability) to:
  - If gate on: turn off
  - If gate off but was originally on: turn on
  - If gate off and was never on: create new random note
- Both branches apply same logic to same steps

**5. Time Shift**
- Shifts pattern by m steps where m is chosen from 0 to pattern_length using weighted distribution
- Distribution: P(m) = x^m · (x-1)/(x^(n+1)-1) where x = shift_freedom parameter
- Special case: if m = pattern_length, reverse the sequence instead of rotating
- Branch A: Rotate forward by m steps (or reverse if m = n)
- Branch B: Rotate backward by m steps (or reverse if m = n - reverse is its own inverse)
- Shift freedom controls distribution:
  - x = 0: always m = 0 (no shift)
  - x = 1: uniform distribution over all m
  - 0 < x < 1: favors smaller shifts
- Preserves all note data, changes timing/position/order

All random values are pre-generated when tree is built, so the same path always produces the same result.

## Installation

1. Copy the `thorns` folder to `~/dust/code/`
2. Restart norns or run `SYSTEM > RESTART` from the norns menu
3. Select `THORNS` from the norns script selection

## Tips

- Start with Branches = 0 to just hear your trunk pattern with scale quantization
- Increase Branches gradually to explore deeper transformations
- Sweep Path slowly to hear smooth transitions through transformation space
- Use short patterns (4-8 steps) for rhythmic variation
- Use longer patterns (12-16 steps) for melodic development
- Try different scales - quantization happens at output, so transformations work in chromatic space
- Adjust transformation probabilities to control how often each type applies
- Set a transformation probability to 0.0 to completely disable it
- Set a transformation probability to 1.0 to always apply it
- Try combinations - for example, high pitch mod + low velocity mod for melodic variation with consistent dynamics
- Lower Shift Freedom (< 0.3) for subtle rhythmic variations
- Higher Shift Freedom (> 0.7) for more dramatic pattern rearrangement
- Transformations stack - multiple can apply to the same branch, creating complex combinations

## Credits

Inspired by Qu-Bit Electronix Bloom hardware sequencer.
This is an independent implementation with different features and approach.
Not affiliated with or endorsed by Qu-Bit Electronix.

Built for norns.

## License

Copyright (c) 2025 Marc Pelath

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
