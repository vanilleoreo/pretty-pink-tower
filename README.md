# pretty-pink-tower

Roblox game **Cherry Blossom Tower**. Scripts are edited in VS Code and live-synced into Roblox Studio with [Rojo](https://rojo.space).

## What lives where

| Folder | Becomes in Studio |
| --- | --- |
| `src/server/` | `ServerScriptService` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts` |
| `src/shared/` | `ReplicatedStorage.Shared` (used by both server and client, e.g. gamepass IDs) |
| `src/character/` | `StarterPlayer.StarterCharacterScripts` |
| `pretty-pink-tower.rbxl` | Backup of the whole place (map, models, free-model scripts) |
| `art/` | Game icon (`icon.png`, 512×512) and thumbnails (`thumbnail*.png`, 1920×1080: main, climb, sofa, ASMR) to upload on the Creator Hub. Redraw with `python3 art/make_art.py && art/render.sh` |

File names decide the script type:

- `Name.server.luau` → Script
- `Name.client.luau` → LocalScript
- `Name.luau` → ModuleScript

Everything else (Workspace models, tools, givers) is still edited in Studio.

## Daily workflow

1. Open this folder in VS Code. The **Rojo: serve** task starts automatically.
2. Open the game in Roblox Studio. The Rojo plugin reconnects by itself
   (the very first time: click **Connect** on the Rojo popup).
3. Edit files in `src/` and save. Changes show up in Studio immediately.
4. Press Play in Studio to test, then **File → Publish to Roblox** to make it live.
5. Commit and push in VS Code to back it up on GitHub.

If sync is not running: in VS Code run **Terminal → Run Task… → Rojo: serve**.
