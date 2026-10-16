# Gaze · PHX v0.6.2

**Author:** Mr.Bear  
**Platform:** Ashita 4 · Phoenix XI

Gaze provides a single eye interface for opening public Phoenix character profiles and Wiki pages from your selected target. It keeps the interface simple, with no additional windows or menus.

## Bugfix v0.6.2 ##

Gaze v0.6.2 fixes an issue where opening browser links in mode 2 could crash XiUI and disrupt its saved layout. Browser links now open through a separate hidden helper process instead of invoking the Windows URL handler inside the game process. Automatic browser opening is preserved, and initial in-game testing was successful. No new features were added.

This should prevent xiui crashing when launching urls.

## What's new in v0.6.1

### Browser mode by default

Clicking the eye now opens the associated page in your default browser. Existing saved mode preferences are preserved. Clipboard mode remains available through `/gaze mode 1`.

### Player profile commands

Use `/gaze @PlayerName` to open a named player's Phoenix profile, or `/gaze @<t>` and `/gaze @` to open the targeted player's profile. These commands always attempt to open the browser, regardless of your eye click mode.

### Testimony recognition

Mobs that can drop testimonies display the appropriate job icon, with artwork for all 18 supported jobs. Clicking opens the testimony's official Phoenix Wiki page.

Testimony recognition is enabled by default and can be changed with `/gaze testimonies on` or `/gaze testimonies off`.

### AF coffer keys and coffers

Zone detection identifies key mobs and Treasure Coffers associated with AF armor quests. Coverage includes 14 coffer zones and 15 key mob zones, including Davoi.

Key mobs and coffers display their own icons and link to the appropriate Phoenix Wiki pages. When a mob drops both a testimony and a key, the testimony icon includes a small clickable key badge. Click the badge for the key page or the main icon for the testimony page.

Coffer recognition is enabled by default and can be changed with `/gaze coffers on` or `/gaze coffers off`.

### Self targeting

Targeting yourself keeps the eye closed. Gaze ignores your own player when using profile commands and does not add you to recent history.

### Manual placeholder management

Add, remove and list custom placeholders directly in game. Entries are saved in a labeled manual section of `placeholders.lua`, with a backup created whenever an entry changes. Changes take effect without reloading.

Full server IDs are supported. Three digit hexadecimal IDs are also accepted after verification against the targeted mob. Gaze saves the full server ID to prevent collisions between zones. Removing a manual override restores the original curated entry.

### Identification priority and click handling

Placeholder identification takes priority over every other category, including in zones where ordinary NM recognition is excluded. NM identification takes priority over testimony and key indicators.

Additional checks prevent stale links from opening after target or zone changes.

## Using Gaze

Select another player to access their public Phoenix profile. Select a recognized NM or matching placeholder to access the associated NM's Wiki page. Supported testimony mobs, key mobs and coffers display their corresponding icons and links.

Most target changes require the target to remain selected for half a second before the eye updates. This reduces rapid icon changes while cycling through targets. Your own player is ignored immediately.

Gaze remembers recently accessed players and displays their visited eye state. Use `/gaze clear` to clear this history while preserving your settings.

The selected link mode persists across reloads. Mode 2 opens the browser; mode 1 copies the URL to the clipboard. Explicit profile commands beginning with `@` always open the browser.

## Commands

### Links and profiles

| Command | Behavior |
| :--- | :--- |
| `/gaze` | Show or hide the eye. |
| `/gaze mode` | Display the current link mode. |
| `/gaze mode 1` | Copy links to the clipboard when clicking the eye. |
| `/gaze mode 2` | Open links in the browser when clicking the eye. Default for new settings. |
| `/gaze @PlayerName` | Open the named player's Phoenix profile. |
| `/gaze @<t>` | Open the targeted player's Phoenix profile. |
| `/gaze @` | Open the targeted player's Phoenix profile. |
| `/gaze help` | Display command help. |

### Recognition

| Command | Behavior |
| :--- | :--- |
| `/gaze testimonies on` or `/gaze testimonies off` | Enable or disable testimony recognition. |
| `/gaze testimonies` | Display the testimony setting. |
| `/gaze coffers on` or `/gaze coffers off` | Enable or disable AF key and coffer recognition. |
| `/gaze coffers` | Display the coffer setting. |

### Manual placeholders

| Command | Behavior |
| :--- | :--- |
| `/gaze ph add "NM Name" "PH Name" ID` | Add or update a manual placeholder. |
| `/gaze ph remove ID` | Remove a manual entry or override. |
| `/gaze ph list` | List manual entries. |

Use double quotes around names containing spaces. Enter the exact PH target name. The NM argument accepts a name, a Wiki page slug or a full Phoenix Wiki page URL.

For a short ID such as `07B`, target the named mob first. Gaze verifies both its name and ID before saving. Three digit IDs are interpreted as hexadecimal, including values such as `007`. Full decimal server IDs and full hexadecimal IDs prefixed with `0x` can be entered without a target. Removing an entry by short ID requires targeting the corresponding mob.

Preserve the manual section of `placeholders.lua` when upgrading. Replacing that file with a fresh copy also replaces your manual entries. Backups are stored beside it with names beginning `placeholders.lua.before-manual-`.

### Appearance and recent history

| Command | Behavior |
| :--- | :--- |
| `/gaze move` | Toggle dragging to reposition the eye. |
| `/gaze size 1`, `/gaze size 2` or `/gaze size 3` | Set the eye size to 40, 56 or 72 pixels. |
| `/gaze size` | Display the current size. |
| `/gaze recent N` | Set the recent player limit from 1 to 18. |
| `/gaze recent` | Display the current limit. |
| `/gaze clear` | Clear recent player history while preserving settings. |
| `/gaze reset` | Restore the eye's position, size and visibility. Feature preferences are preserved. |

## Release notes

The approved v0.4.1 functionality forms the base of this release. Its NM and placeholder links, player eye states, saved link modes, recent history controls and target delay are established features.

The v0.6.1 additions have passed automated checks using a simulated Ashita environment. In game testing remains. This version is submitted for review; approval of v0.4.1 does not imply approval of the additions in v0.6.1.

Coffer icons identify supported sources; they do not check quest progress or guarantee an AF reward. Some mapped Wiki mob name aliases still require confirmation in game. Source details are retained in `COFFER-SOURCES.json`.
