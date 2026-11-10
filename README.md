Poop Engine (Haxe / HaxeFlixel)

Poop Engine is a Friday Night Funkin' engine made with mobile devices in mind. It takes inspiration from Kade Engine, especially its chart format, note judgments and gameplay mechanics.

The engine uses touch hitboxes for gameplay and gestures for navigating menus, while keeping the familiar look and feel of the original game.

APK builds are automatically handled through GitHub Actions.

Features

- Kade / Vanilla chart support – Uses the familiar chart format.
- Note judgments – Sick, Good, Bad and Shit.
- Ghost Tapping – Can be enabled or disabled.
- Touch Controls – Four invisible hitboxes cover the gameplay screen.
- Gesture Navigation – Swipe to navigate menus and select options.
- Mod Support – Load external mods with custom songs, characters, stages, scripts and more.
- HScript Support – Customize gameplay and menus without recompiling the engine.
- Chart Editor – Create and edit charts directly in the game, including timeline events and character changes.
- Custom HUDs – Replace or modify gameplay elements through scripts.
- Shaders – Support for custom GLSL shaders.
- Options Menu – Gameplay, graphics, interface, controls, language and update settings.
- In-game Updates – Check for new commits and install newer builds.
- 3D Rendering – Additional rendering support.

Controls

Android

- Tap a lane to hit notes.
- Hold a lane to hit sustain notes.
- Swipe up/down to navigate menus.
- Tap the selected item to confirm.
- Swipe right or use the back button to return.

PC

- D, F, J, K or arrow keys for gameplay.
- ENTER to confirm.
- ESC to go back.
- TAB to open mod selection.
- R to reload mods.
- E to open the chart editor.

Modding

Most content can be customized without modifying the engine's source code.

Mods use their own folder structure and can include:

- Songs and charts
- Characters and stages
- Images, sounds and music
- HScript scripts
- Modcharts
- Custom HUDs
- Menu modifications
- Languages
- Shaders
- Custom options

On Android, mods are stored in:

"/storage/emulated/0/.PoopEngine/mods/"

On PC, they are stored in a "mods/" folder next to the executable.

Files inside an active mod can replace their corresponding base-game files.

You can find example mods in the "example_mods/" directory.

Chart Editor

The engine includes a built-in chart editor with a timeline-based layout.

It supports note placement, sustain notes, selection tools, snapping, zoom, audio playback, BPM settings and section camera control.

The Events tab lets you add events at the current playhead position, browse them, change their type/value/target, move them to the playhead and remove them. Supported event types:

- `zoom` – Change the gameplay camera zoom.
- `camera` – Focus the camera on the player or opponent.
- `hud` – Show or hide the HUD.
- `bpm` – Change the BPM during the song.
- `character` – Change the active player-side or opponent-side character.

Charts can include a `characters` array containing every character ID used by the song. Character events select an ID from this list (the editor also discovers character JSON files from the active mod and built-in assets). Event entries use `step`, `type`, `value` and `target`, for example:

```json
{
  "characters": ["bf", "dad", "bf-dead"],
  "events": [
    {"step": 64, "type": "zoom", "value": 1.2, "target": "player"},
    {"step": 128, "type": "character", "value": "bf-dead", "target": "player"},
    {"step": 192, "type": "bpm", "value": 150, "target": "player"},
    {"step": 256, "type": "hud", "value": false, "target": "player"}
  ]
}
```

Charts are saved in the Kade / Vanilla format, making them compatible with the engine's chart system.

Updates

Poop Engine includes a GitHub update system.

The update menu displays information about the build, including its commit hash, author, branch and build date. It can also check for newer commits and download the latest nightly APK directly from the game.

Builds are generated automatically through GitHub Actions.

Credits

- yussiw – Engine development.
- Codename Engine – Assets and original resources used in the project.
- Kade Engine – Inspiration and code reference.

Development Status

Poop Engine is still a work in progress. Features and systems may change as development continues.