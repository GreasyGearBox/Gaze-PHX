# Gaze v0.6.1 submission notes

## Purpose

Gaze provides an on screen shortcut to public Phoenix character profiles and Wiki pages. It identifies supported content from the selected target and displays the corresponding eye, job, key or coffer icon. A click or explicit profile command opens the associated page or copies its URL.

## Recognition and priority

The addon reads target name, server ID and spawn flags through Ashita, along with the current zone and local player identity. It uses bundled lookup tables.

Placeholders require a full server ID and matching name. They take priority over NM, testimony and key recognition. NMs are matched by name, with existing zone exclusions. Testimonies are matched by mob name. AF keys and coffers are matched by zone and name.

The current package includes 387 curated placeholder entries, 126 testimony drop entries across 18 jobs, 108 key drop entries across 15 zones and 14 coffer destinations. Manual placeholder entries are empty in the submitted package.

## User actions and local storage

The icon changes automatically after a target remains selected for 500 ms in most target transitions. Self targeting is ignored immediately. Opening a page requires an eye click or an explicit `/gaze @` profile command.

Browser links use the Windows URL handler through ShellExecuteA. Eye clicks respect the saved mode; explicit profile commands always open the browser. Profile commands do not verify that the requested character page exists.

Settings store position, size, visibility, link mode, feature switches and recent player history. Manual PH commands write the labeled section in `placeholders.lua` and retain a backup beside that file. A manual correction can override a curated entry; removing it restores the curated entry.

## Sources

Phoenix Wiki page URLs are retained in the bundled data. Testimony records include source revisions. `COFFER-SOURCES.json` retains coffer and key source details, zone IDs and explicit name aliases. The addon uses local data without runtime Wiki fetching.

## Validation and remaining checks

Automated LuaJIT checks using a simulated Ashita environment covered existing testimony, coffer and PH data, profile commands, manual entry persistence and rollback, overlap behavior, self targeting, link modes and target transitions. Default mode configuration and ZIP integrity were also checked.

Actual Ashita behavior, browser launch, filesystem permissions, icon readability and candidate Wiki name aliases still require in game verification. Matching names does not distinguish level variants with the same name. Coffer indicators do not check quest progress or guarantee a reward.

This document describes the submitted version and does not establish staff approval. The approved v0.4.1 release is the baseline; the additions in v0.6.1 are submitted for review.
