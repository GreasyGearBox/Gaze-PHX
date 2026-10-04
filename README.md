# Gaze - PHX v0.4.1

Author: Mr.Bear. Ashita 4.

Gaze provides a single-eye interface for accessing public Phoenix character profiles and NM wiki pages from your selected target. Clicking the eye copies or opens the associated page depending on the mode setting. The design remains intentionally minimalistic, with no additional windows or menus.

## Changes included in this release

- Added NM and placeholder wiki links. The placeholder list contains 305 published IDs associated with 228 NM pages, sourced from the Phoenix wiki.
- Added a fourth eye state for supported NMs and matching placeholders. Both link to the associated NM’s wiki page.
- Includes clipboard and browser modes, introduced in v0.3.0, for copying or opening the associated page.
- Added `/gaze clear` to clear recent-player history and immediately refresh the player eye while preserving your settings.
- Increased target debounce from 200 ms to 500 ms. A target must remain selected for half a second before its eye state updates, reducing rapid eye changes while tabbing through targets.
- Preserved the existing player eye states and recent-player memory.

## New chat commands

- `/gaze clear` — clear recent-player history while preserving your settings. Added in v0.4.1.
- `/gaze mode 1` — copy the associated URL to the clipboard when clicking the eye. Default mode.
- `/gaze mode 2` — open the associated URL in your default browser when clicking the eye.
- `/gaze mode` — display the current mode.

The mode commands were introduced in v0.3.0. Both modes support player profiles, NM pages, and placeholder links. The selected mode persists across reloads.
