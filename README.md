[README.md](https://github.com/user-attachments/files/32916770/README.md)
# Gaze - PHX

**Version:** 0.1.0  
**Author:** Mr.Bear  
**Platform:** Ashita 4

## Summary

Gaze adds a small eye-shaped HUD button.

When another player is targeted, clicking the eye copies that player's Phoenix character-profile URL to the clipboard.

## Eye States

- **Dim closed eye** — target is not a player.
- **Full-color closed eye** — player targeted, not recently gazed.
- **Open eye** — player was recently gazed.

A short target delay prevents rapid flickering while cycling targets.

## Recent Players

Gaze keeps a small local list of recently gazed players.

- Default: 5
- Configurable: 1–18
- Retargeting someone on the list shows the open eye.
- Gazing them again moves them back to the top.

## Commands

`/gaze` — show/hide  
`/gaze move` — move mode  
`/gaze size 1-3` — set size  
`/gaze recent 1-18` — set recent-list size  
`/gaze reset` — reset position and size  
`/gaze help` — command list

## Technical Notes

Gaze uses Ashita's normal target/entity access, local primitives, mouse events, settings, and clipboard support.
