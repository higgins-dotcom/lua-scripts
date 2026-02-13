# Necromancy Rituals

RS3 script for performing Necromancy Rituals with GUI configuration.

## Features

- Automated ritual performance at Necromancy zone
- Configurable disturbance handling:
  - Moth
  - Wandering Soul
  - Sparking Glyph
  - Shambling Horror
  - Corrupt Glyphs
  - Soul Storm
  - Defile

- GUI with configurable settings:
  - Auto Run (bypass Start button)
  - Max idle time (5-15 minutes)
  - Individual disturbance toggles
  - Real-time status display
  - Per-character config saving

## Setup

1. Place `NecroRituals.lua` in your scripts folder
2. Create a `configs` folder next to the script
3. Run the script

## Configuration

Settings are saved to `configs/necrorituals-<character>.config.json`

### GUI Options

- **Auto Run**: Bypasses Start button on script launch
- **Max Idle Time**: Minutes before AFK check (5-15)
- **Disturbances**: Toggle individual disturbances on/off

## Author

Higgins

## Version

### v3.0 (Major Update)
- Updated main script to use NecroGUI module
- Added status tracking (Ritual Active, Repairing, Idle, etc.)
- Configurable disturbance handling per user preference
- Auto Run feature with character-specific config files

### v2.7 (Original)
- Basic script functionality