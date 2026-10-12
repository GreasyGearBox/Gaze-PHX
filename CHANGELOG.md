# Gaze changelog

## v0.6.1

Changes since the approved v0.4.1 release.

### Profiles and link behavior

Browser mode is now the default for new settings. Existing saved mode preferences are preserved.

Added `/gaze @PlayerName`, `/gaze @<t>` and `/gaze @` to open player profiles directly. Your own player is ignored by target recognition, profile commands and recent history updates.

### Testimonies and AF coffers

Added testimony recognition with 18 job icons and links to official Phoenix Wiki testimony pages.

Added zone detection for AF key mobs and Treasure Coffers, covering 14 coffer zones and 15 key mob zones. Mobs with both testimony and key drops show a separate clickable key badge.

Added independent testimony and coffer switches, both enabled by default.

### Placeholders

Added commands to add, remove and list manual placeholders. Entries are stored in a labeled section of `placeholders.lua`, with backups and immediate updates.

Added support for full server IDs and three digit hexadecimal IDs verified against the targeted monster. Removing a manual override restores the curated entry.

PH identification takes priority over all other categories, including zones where ordinary NM recognition is excluded. NM recognition takes priority over testimony and key indicators.

### Click handling

Added checks against stale targets and zone changes before opening links.

## Established functionality through v0.4.1

Player profiles, NM and placeholder Wiki links, player eye states, saved clipboard and browser modes, configurable recent history, `/gaze clear`, movable and resizable artwork, and a 500 ms target delay form the approved release baseline.
