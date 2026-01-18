# Integrating nb into Thorns

## What Changed

### 1. Project Structure
Add nb as a git submodule:
```bash
cd ~/dust/code/thorns
git submodule add https://github.com/sixolet/nb.git lib/nb
```

### 2. Code Changes to thorns.lua

**Removed:**
- `engine.name = 'PolyPerc'` declaration
- PolyPerc-specific parameters (release, cutoff, gain)
- Direct `engine.amp()` and `engine.hz()` calls

**Added:**
- `local nb = require 'nb/lib/nb'` - Load nb library
- `local voice_player` - Variable to hold nb voice player
- `nb:init()` in `init()` - Initialize nb
- `nb:add_param("voice", "Voice")` - Add voice selector parameter
- `nb:add_player_params()` - Add voice-specific parameters
- `voice_player = params:lookup_param("voice"):get_player()` - Get player reference
- `voice_player:play_note(midi_note, vel, 0.9 * 1/4)` - Play notes via nb

### 3. User Benefits

**Before (PolyPerc only):**
- Fixed to one basic percussion synth
- Limited sound shaping (release, cutoff, gain)

**After (nb ecosystem):**
- Choose from any installed nb voice:
  - emplaitress (MI Plaits - 16 synthesis modes)
  - doubledecker (2-layer CS-80 style synth)
  - polyperc (original PolyPerc if preferred)
  - mx.synths (piano, epiano, organ, etc.)
  - drumcrow (crow as synthesizer)
  - Many more community voices
- Each voice has its own parameters
- Can switch voices without changing code
- Future nb voices automatically compatible

### 4. Installation Steps for Users

1. **Install nb voices** (one-time setup):
   ```
   ;install https://github.com/sixolet/emplaitress
   ```
2. **Enable voice in MODS:**
   - SYSTEM > MODS > emplaitress > enable (+)
   - SYSTEM > RESTART
3. **Load Thorns and select voice:**
   - PARAMETERS > Voice > select "emplaitress 1"
   - Adjust voice parameters as desired

### 5. Key Technical Details

**Note Duration:**
nb expects duration in beats (clock time), not seconds:
```lua
-- 90% of a 16th note (1/4 beat)
voice_player:play_note(midi_note, vel, 0.9 * 1/4)
```

**Voice Player Access:**
The player is retrieved from the param, not stored directly:
```lua
voice_player = params:lookup_param("voice"):get_player()
```

**Parameter Organization:**
nb automatically adds voice-specific params under the voice selector.
Each voice can have different parameters (envelopes, filters, LFOs, etc.)

### 6. Compatibility

**Output Modes still work:**
- Audio: Uses selected nb voice
- MIDI: Uses MIDI output (unchanged)
- Both: Both audio and MIDI

**Existing features unchanged:**
- Grid interface
- Transformations
- Tree navigation
- Scale quantization
- All encoders/keys

## Available nb Voices (Examples)

### Synth Engines
- **emplaitress** - MI Plaits (16 synthesis modes, polyphonic)
- **doubledecker** - 2-layer CS-80 style synth
- **polyperc** - PolyPerc (1-6 instances)
- **mx.synths** - Collection: piano, epiano, casio, organ, etc.

### Hardware Integration
- **drumcrow** - Crow as synthesizer (4-8 voices)
- **ansible** - Ansible CV/gate
- **Just Friends** - Just Friends eurorack
- **w/syn** - w/syn eurorack

### Utilities
- **nb_midiconfig** - Custom MIDI device configs
- **nb_router** - Route notes to multiple voices

## Why nb?

1. **Modularity** - Users install only voices they want
2. **Consistency** - Same API for all voices
3. **Community** - New voices added regularly
4. **Flexibility** - Switch sounds without changing scripts
5. **Integration** - Works with other nb-compatible scripts

Your script becomes part of the nb ecosystem alongside:
- dreamsequence
- arcologies  
- n.kria
- tetra
- mosaic
- and many more
