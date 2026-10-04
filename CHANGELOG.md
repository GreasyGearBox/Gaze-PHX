# Gaze - PHX v0.4.1 Changelog

- Increased target debounce from 200 ms to 500 ms. A changed supported target must remain unchanged for half a second before its eye state updates, reducing rapid eye changes while tabbing through targets. The previous eye appearance can remain visible during this delay.
- Added `/gaze clear` to clear recent-player history and immediately refresh the player eye.
- Clearing history preserves the recent-player limit, position, size, and link mode.

# 0.4.0 — Experimental 2

- Add shared garnet/antique-gold fourth eye for NMs and confirmed PHs.
- Add 305 Phoenix-wiki PH IDs with strict ID + name matching.
- PH clicks use associated NM wiki page in clipboard/browser modes.
- Preserved player eye states and recent-player memory.
- No additional windows or menus.

# Changelog

## 0.3.0 Experimental

- Added persistent link modes: clipboard (default) and browser.
- Added /gaze mode 1, /gaze mode 2, and current-mode query.
- Browser launch happens only after a deliberate eye click.
- Browser failures report an error without marking a player as recently gazed.

## 0.2.0 Experimental

- Added local NM-name recognition sourced only from the Phoenix Wiki Notorious Monsters list.
- Recognized NMs use the full-color closed-eye state.
- Clicking a recognized NM copies its Phoenix Wiki URL to the clipboard.
- Player behavior and recent-player memory are unchanged.
- Elementals and selected generic NM categories are excluded.

## 0.1.0

Initial proof-of-concept baseline.

- Three-state eye HUD.
- 200 ms target debounce.
- Player-target detection.
- Deliberate click-to-copy Phoenix character profile URL.
- Three fixed size presets.
- Movable HUD position.
- Bundled local artwork.
- Persistent recent-gazed list with configurable capacity from 1 to 18.
- No browser launch, web requests, packet handling, gameplay-command injection, or gameplay automation.
