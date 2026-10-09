# Gaze - PHX

**Author:** Mr.Bear  
**Platform:** Ashita 4 on Windows · Phoenix XI  
**Code baseline:** v0.4.1

## Update 10-8-2026 ##

Updated placeholders.lua with 82 additional placeholder IDs covering 57 NMs since v0.4.1. Gaze now supports 387 placeholder IDs across 285 NMs, checked against the Phoenix wiki. These additions expand placeholder recognition without changing addon functionality. See PLACEHOLDER-ADDITIONS.md for the full list.


-----------------------------------------------------------------------------------


Gaze is a small HUD addon that connects your selected target to public Phoenix character profiles and wiki pages. The eye reacts to your selected target with a visual change after a short delay. Supported targets include players, recognized Notorious Monsters (NMs), and placeholders (PHs). Click the eye to copy the associated link or open it in your default browser.

Player targets link to their character profiles. Recognized Notorious Monsters (NMs) link to their Phoenix wiki pages. Supported placeholders (PHs) link to the page for the NM they can spawn. Gaze keeps the interaction in one movable eye, without additional windows or menus.


PHX is project and package branding. The addon folder, Lua entry point, and in-game name are **gaze**.

## Eye states

| Appearance | Meaning | Click destination |
|---|---|---|
| Dim closed eye | No supported target | None |
| Full-color closed eye | Player whose profile is not in recent history | That player's Phoenix profile |
| Original open eye | Player whose profile is in recent history | That player's Phoenix profile |
| Garnet / antique gold open eye | Recognized NM or matching placeholder | The associated NM's Phoenix wiki page |

NM and PH targets share the fourth eye state and retain it after clicking. They are not added to recent-player history.

The eye reacts automatically when you select a player, recognized NM, or supported placeholder. This is a visual change after a **500 ms (half-second) delay** to reduce flickering; selecting a target does not copy a link or open a browser. Those actions require clicking the eye. The previous appearance can remain visible during that delay. Gaze checks the live target again when you release the mouse button; a stale appearance cannot activate a different target's link.

## Installation

1. Create a folder named gaze.
2. Download and extract the repository ZIP.
3. Copy the extracted addon files and assets folder into the gaze folder you made.
4. Move the gaze folder into C:\Games\PhoenixXI\addons (or your installation’s addons folder).
5. Run /addon load gaze.

***If you do not have your resolution set correctly in your launcher clicking the eye will not work as expected. Fix your resolution***

## Recommended config.

1. /gaze mode 2 (launching URLs instead of copying to clipboard)
2. /gaze move (move it then '/gaze move' again to lock it)
3. /gaze size 1, 2, or 3. These are preset sizes.

## Using Gaze

Clipboard mode is the default. Select a supported target and click the eye, then paste the link into your browser.

Use '/gaze mode 2' to open links directly in your default browser after clicking. Browser mode does not also copy the URL. If launching fails, Gaze reports an error; use '/gaze mode 1' to return to clipboard mode.

To move the eye, run '/gaze move', drag it with the left mouse button, and run '/gaze move' again to finish. While move mode is enabled, dragging replaces link activation.

## Commands

| Command | Effect |
|---|---|
| /addon load gaze | Load the addon. |
| /addon unload gaze | Unload the addon. |
| /addon reload gaze | Reload addon files. |
| /gaze | Toggle the eye's visibility. |
| /gaze mode | Display the current link mode. |
| /gaze mode 1 | Copy links to the clipboard; default. |
| /gaze mode 2 | Open links in the Windows default browser after clicking. |
| /gaze move | Toggle left-mouse dragging. |
| /gaze size | Display the current size and available preset range. |
| /gaze size 1 | Set the eye to 40 × 40 pixels. |
| /gaze size 2 | Set the eye to 56 × 56 pixels; default. |
| /gaze size 3 | Set the eye to 72 × 72 pixels. |
| /gaze recent | Display the recent-player memory limit. |
| /gaze recent N | Set the memory limit to a whole number from 1–18; default 5. |
| /gaze clear | Clear recent-player history and refresh the stable player eye. Preserve the memory limit, position, size, visibility, and link mode. |
| /gaze reset | Restore position to x=40, y=40 and size to 56 × 56 pixels, show the eye, and disable move mode. Preserve link mode, recent history, and its limit. |
| /gaze help | Print the in-game command list. |


## Recent-player memory

Successfully copying a player's profile link or launching it in browser mode adds their name to a persistent local list. Gazing the same player again moves them to the front. The default for recent players is 5. Gaze supports 1-18 recents. Change the limit with '/gaze recent' followed by a number from 1 to 18.

Retargeting a remembered player shows the original open eye. 

Position, size, visibility, link mode, recent-player names, and the memory limit are saved locally. 

## Recognition and coverage

- NM recognition uses a bundled name allowlist sourced from the [Phoenix wiki NM index](https://wiki.phoenix-xi.com/Notorious_Monsters). It is name matching, not full-ID validation of every NM.
- Placeholder recognition requires both the mob to be targeted and match both the name and ID listed on the Phoenix Wiki. Same named ordinary mobs with different IDs are not recognized as PH.
- A known PH ID with a mismatched name remains unsupported rather than falling back to NM name matching.
- Elementals, Mimic, Chigoe, and generic Hobgoblin/Halforc/Theoyagudo/Metaquadav job-name groups are excluded from NM-name recognition.

## Technical behavior

Gaze reads the current main target through Ashita. Target recognition uses local bundled tables; targeting does not make web requests. Clicking constructs a Phoenix profile or wiki URL and copies it, or passes it to Windows' default URL handler in browser mode.

The code does not enumerate nearby entities, monitor NM spawns, provide spawn timers, claim targets, move the character, issue combat commands, send game packets, or write game memory.

## Troubleshooting

- **Addon will not load:** check addons\gaze\gaze.lua and ensure all supporting Lua files are present.
- **Eye is missing:** run /gaze reset to show it at its default position and size; check that the artwork is present.
- **Click drags instead of opening a link:** disable move mode with /gaze move.
- **Click does nothing after changing targets:** wait for the new target's eye state. Unsupported targets have no link.
- **Browser launch fails:** use /gaze mode 1 and paste the copied URL manually.
- **Expected PH remains dim:** Check the wiki manually. Confirm it is indeed a placeholder listed for Phoenix. Contact Mr.Bear.
