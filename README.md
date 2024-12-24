# Binding of Isaac: Repentance+ Online Co-op with Mods (Without Desyncs)

A guide on how to set up **online co-op** for *Binding of Isaac: Repentance+* with mods enabled, ensuring no desync issues.

This repository includes two mods of my own making(based on truecooptreasure and eid respectively)
- **Two-Treasure Mod:** Spawns 2 items in every treasure room(good for 2 players, might need editing for more than that).
- **Descriptions Mod:** Displays item descriptions in-game(same idea as eid, but different process, causes no desyncs).

---

## 📋 Instructions

### 1. Locate the `main.lua` File
1. Navigate to your **Binding of Isaac** game folder.
2. Go to the `resources/scripts` directory.
3. Find the file named `main.lua`.

### 2. Choose Your Modification Method
You have two options:

#### Option 1: Replace `main.lua`
1. Download the pre-modified `main.lua` file from this repository (compatible with game version `1.9.7.8`).
2. Replace the existing `main.lua` file in `resources/scripts` with the downloaded one.

#### Option 2: Manually Add Mod Scripts
1. Open `main.lua` in a text editor (e.g., Notepad++).
2. Scroll to the **bottom** of the file.
3. Paste the code snippets from the provided files:
   - [`two-treasure-mod-separate.txt`](./two-treasure-mod-separate.txt)
   - [`descriptions-mod-separate.txt`](./descriptions-mod-separate.txt)
4. Save the file.

> **Note:** The mods must be appended to the bottom of the `main.lua` file to work properly.

---

## 🔍 How It Works
Instead of using traditional mod folders, we inject custom mod scripts directly into the game's `main.lua`. Here's why:

- **It prevents mod checking that disables online:** You can't play online with mods(if not using cheat engine to disable or revert checks).

### Example: Two-Treasure Mod
- **Objective:** Add a second treasure item to treasure rooms.
- **How It Works:**
  1. Detects when the player enters a treasure room.
  2. Checks if the room is being visited for the first time.
  3. Spawns an additional item offset from the first item's position(might be a little funky if there are existing blocks in there).

---

### Example: Descriptions Mod
- **Objective:** Display descriptions for items, trinkets, cards, and pills.
- **How It Works:**
  1. Hooks into the `MC_POST_RENDER` event.
  2. Checks proximity to items and whether they are identified.
  3. Renders a description text next to the item(different to how eid does that, this version is uglier, but more consistent for online).

---

## 🛠️ Files in This Repository
- [`main.lua`](./main.lua): `main.lua` file with two mods already added at the bottom.
- [`two-treasure-mod-separate.txt`](./two-treasure-mod-separate.txt): Code snippet for the Two-Treasure Mod.
- [`descriptions-mod-separate.txt`](./descriptions-mod-separate.txt): Code snippet for the Descriptions Mod.

-**Caution! Either replace your main.lua with the one from this repo or just add mods from here to the bottom of your main.lua, not both!**

---

## 🚨 Disclaimer
These modifications are tested for **Binding of Isaac: Repentance+ (v1.9.7.8)**. Compatibility with other versions or modded setups is not guaranteed.

If you wanna write your mods that work in online, just write them like normal mods, but don't register them as mods while hooking to game methods:
Isaac.AddCallback(nil, ModCallbacks.MC_POST_NEW_ROOM, onNewRoom)
instead of
Isaac.AddCallback(ModName, ModCallbacks.MC_POST_NEW_ROOM, onNewRoom)

But be careful, since even slight differences between players' game states may cause heavy desyncs.
Do not utilize random generation and similar stuff.