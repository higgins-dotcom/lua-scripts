# Easy Clue Solver

A comprehensive automated clue scroll solver for RuneScape 3 that handles Easy, Medium, Hard, and Elite clue scrolls with intelligent puzzle-solving capabilities.

## 📋 Overview

The Easy Clue Solver is an automated solution that takes the tedium out of solving clue scrolls. It consists of two main components:

- **LeaguesClueSolver.lua** - The main script that handles clue identification, navigation, and completion
- **PuzzleModule.lua** - A specialized module for automatically solving slide puzzles and other puzzle-based clue challenges

### Key Features

- ✅ Automatically solves all clue scroll difficulties (Easy, Medium, Hard, and Elite)
- ✅ Intelligent puzzle solver for slide puzzles and knot puzzles
- ✅ Auto-teleportation to clue locations using Globetrotter equipment
- ✅ Smart clue swapping for unsolvable or unwanted clues
- ✅ Handles dig clues, scan clues, NPC interactions, and object interactions
- ✅ Supports medium clues with item requirements and foot-shaped key unlock
- ✅ Comprehensive metrics tracking and progress reporting

## 🔧 Prerequisites

Before you begin, make sure you have the following:

### In-Game Requirements

- **Globetrotter Jacket** - Must be equipped and on your action bar (used for teleporting)
- **Globetrotter Backpack** - Must be equipped and on your action bar (used for clue swapping)
- **Clue Scrolls** - Easy, Medium, Hard, or Elite clue scrolls (sealed or unsealed)

### Optional Unlocks

- **Way of the foot-shaped key** - Allows skipping item requirements for medium clues (highly recommended)

## 📝 Step-by-Step Setup Guide

Follow these steps carefully to get the Clue Solver up and running:

### Step 1: Register for API Access

The Clue Solver uses an external API to solve complex puzzles. You'll need to register for access:

1. Visit **https://api.rs3bot.com** in your web browser
2. Click on the registration/sign-up option
3. Complete the registration process to create your account
4. Once logged in, locate and copy your **API token**
   - This token is a unique identifier that looks like: `dk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Keep this token secure and private

### Step 2: Configure Your API Token

Now you need to add your API token to the script:

1. Open the **LeaguesClueSolver.lua** file in a text editor
2. Locate line 40, which contains the `API_TOKEN` configuration
3. Replace the existing token with your personal API token

**Example:**

```lua
local SETTINGS = {
    PROXIMITY_THRESHOLD = 5,
    API_TOKEN = "dk_your_token_here", -- Add your API token here for puzzle solver authentication
    ALLOW_WILDERNESS_TELEPORTS = false,
    ALLOW_REQUIRED_ITEM_CLUES = false,
    HAS_FOOT_SHAPED_KEY_UNLOCK = false,
}
```

**Replace** `dk_your_token_here` **with your actual token from Step 1.**

4. Save the file after making the change

### Step 3: Configure Bot Allowed Hosts

The bot needs permission to communicate with the puzzle-solving API:

1. Open your bot's settings panel
2. Navigate to the **Network** or **Security** section (look for "Allowed Hosts")
3. Add the following host to your allowed hosts list:
   ```
   api.rs3bot.com
   ```
4. Save your settings

**Visual Guide:**

![alt-text](https://raw.githubusercontent.com/higgins-dotcom/lua-scripts/refs/heads/main/Leagues/Clues/settings.png)

### Step 4: Configure Optional Settings (Optional)

You can customize the bot's behavior by modifying these settings in **LeaguesClueSolver.lua**:

```lua
local SETTINGS = {
    PROXIMITY_THRESHOLD = 5,
    API_TOKEN = "your_token_here",
    
    -- Set to true to allow wilderness teleports, false to swap wilderness clues
    ALLOW_WILDERNESS_TELEPORTS = false,
    
    -- Set to true to handle clues requiring items from NPCs, false to swap them
    ALLOW_REQUIRED_ITEM_CLUES = false,
    
    -- Set to true if you have "Way of the foot-shaped key" unlock
    -- (skips required items for medium clues)
    HAS_FOOT_SHAPED_KEY_UNLOCK = false,
}
```

**Setting Explanations:**

- **ALLOW_WILDERNESS_TELEPORTS**: Controls whether the bot will teleport to wilderness locations for clues
  - `false` (default) - Wilderness clues will be swapped/skipped
  - `true` - Bot will complete wilderness clues (use at your own risk)

- **ALLOW_REQUIRED_ITEM_CLUES**: Controls whether the bot will handle medium clues that require items from NPCs
  - `true` (default) - Bot will obtain required items
  - `false` - Clues requiring items will be swapped/skipped

- **HAS_FOOT_SHAPED_KEY_UNLOCK**: Indicates if you have the foot-shaped key unlock
  - `true` (default) - Skip item requirements and go straight to chests
  - `false` - Bot will obtain required items normally

## 🚀 Usage Instructions

Once setup is complete, using the Clue Solver is simple:

1. **Launch the Bot** - Start your RuneScape bot client
2. **Load the Script** - Load the LeaguesClueSolver.lua script
3. **Prepare Your Inventory**:
   - Equip Globetrotter Jacket and Backpack
   - Ensure both items are on your action bar
   - Have clue scrolls in your inventory
4. **Start the Script** - Run the script and let it work!

### What to Expect

The bot will automatically:

- ✓ Open sealed clue scrolls and scroll boxes
- ✓ Read and analyze the clue
- ✓ Teleport to the required location
- ✓ Complete dig, scan, or interaction actions
- ✓ Solve puzzle boxes and knot puzzles automatically
- ✓ Swap clues that are emote-based or unsolvable
- ✓ Track and display comprehensive statistics

### Statistics Tracking

The bot provides real-time statistics including:

- Total clues completed (by difficulty)
- Clue types processed (dig, scan, NPC, object, etc.)
- Puzzle boxes and knot puzzles solved
- Clues swapped or skipped
- Runtime and profit tracking

## ❓ Troubleshooting

### Common Issues and Solutions

#### Issue: "Could not authenticate with puzzle API"

**Solution:**
- Verify your API token is correct in the `API_TOKEN` setting
- Ensure `api.rs3bot.com` is in your bot's allowed hosts list
- Check that your API account is active and valid

#### Issue: Bot doesn't teleport to clue locations

**Solution:**
- Confirm Globetrotter Jacket is equipped
- Verify Globetrotter Jacket is on your action bar
- Check that you have charges remaining on the jacket

#### Issue: Bot skips all clues without attempting them

**Solution:**
- Check your settings - you may have restrictive filters enabled
- Verify `ALLOW_WILDERNESS_TELEPORTS` and `ALLOW_REQUIRED_ITEM_CLUES` settings
- Some clue types (like emotes) are automatically swapped - this is normal behavior

#### Issue: Puzzle boxes fail to solve

**Solution:**
- Ensure your API token is valid and has puzzle-solving access
- Check the console for error messages
- The PuzzleModule may need time to analyze complex puzzles - be patient

#### Issue: "Proximity threshold not met"

**Solution:**
- The bot needs to be closer to the clue location
- Try manually moving closer to the indicated area
- Check for obstacles or barriers blocking pathfinding

#### Issue: Bot gets stuck in a loop

**Solution:**
- Stop the script and check the console for errors
- Verify you have all required items equipped
- Try manually completing the current clue step, then restart the script

### Getting Help

If you continue to experience issues:

1. Check the console output for specific error messages
2. Verify all prerequisites are met
3. Ensure both LeaguesClueSolver.lua and PuzzleModule.lua are in the correct directory
4. Try restarting the bot client and reloading the script

## 📊 Performance Tips

To get the best results:

- **Monitor the first few clues** - Ensure the bot is working as expected
- **Use the foot-shaped key unlock** - Significantly speeds up medium clues

## ⚠️ Important Notes

- This bot is designed for efficiency and automation
- Always monitor the bot during initial runs to ensure proper configuration
- Keep your API token private - never share it with others
- Wilderness clues are disabled by default for safety
- Some clue types (emotes) are automatically swapped as they're not fully automated

## 📜 Version Information

- **LeaguesClueSolver Version**: 3.3
- **PuzzleModule Version**: 1.0
- **Author**: Higgins

---

**Happy Clue Solving! 🎉**