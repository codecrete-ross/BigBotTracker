# Big Bot Tracker

<p align="center">
  <img src="logo.png" alt="Big Bot Tracker logo" width="320" />
</p>

Big Bot Tracker is a World of Warcraft Retail and Classic addon that monitors joined public chat channels for repeated advertising patterns.

It is an evidence viewer, not a verdict system. It does not auto-report players, post accusations, block chat, or send public messages. It shows observed chat patterns so you can review them yourself.

## What It Does

- Watches joined public chat channels, ignoring your own messages
- Does not join channels; it only observes public channel messages your client already receives
- Tracks chatters by normalized `character-realm`
- Promotes local candidates only after signals such as repeated templates, near-duplicate wording, regular timing, or high volume with ad-like behavior
- Shows timing, content reuse, activity, persistence, current-channel baseline, and network context
- Keeps local evidence and network evidence separate
- Uses transparent heuristic scoring, not machine learning or external services

Message count alone is not treated as a pattern. Network sync can create `Peer Context Only` entries, but peer evidence does not raise local status, pattern strength, or local evidence.

## Report Window

Open the report with `/bbt`, `/bbt open`, `/bbt show`, `/bigbottracker`, or the addon compartment button.

The table shows a watch toggle, status, character-realm, observed signals, message count, cadence, text reuse, last seen, and source: `Local`, `Net`, or `L+N`.

The filter bar combines local triage filters with a data-driven channel dropdown. The channel list is built from stored local evidence, and `All Channels` also keeps network-only candidates visible.

Selecting a row shows a plain-language assessment first, then detail sections for summary, activity, timing, content, why it was flagged, local channel baseline, peer evidence, and observed signals. The assessment explains what was observed, what it means, and why the current status was assigned.

The timing detail uses user-facing terms: common intervals hide one-off low-signal buckets, tiny retained buckets display as `<1%` instead of `0%`, and stable runs group repeated same-cadence phases so duplicate runs are easier to understand. Click headers to sort and hover rows or headers for field explanations.

`Very Strong Pattern` candidates show a `Report` button. It opens Big Bot Tracker's report assist and tries to open Blizzard's in-world report flow when a reportable player location is available. A successful report-frame open marks the candidate `Reported` locally, but you can clear that status from the assist window or candidate detail if the flow was opened by mistake or not completed. You must choose the Blizzard category, review or paste any text, and submit manually.

The report window defaults to the `Active` filter, which hides locally handled candidates. Handled means `Reported` or `Ignored`. The eye button marks a candidate `Watched`, keeping it visible in `Active` even if it is otherwise handled. These triage states are local, non-destructive display state only; they do not change pattern strength, local evidence, status, sync, or stored evidence.

Available filters:

- `All` shows every stored candidate
- `Active` shows unhandled candidates plus watched candidates
- `Watched` shows watched candidates
- `Reported` shows candidates marked reported
- `Ignored` shows ignored candidates

Other report controls:

- `Refresh` rebuilds the visible report
- `Export` saves a compact debug summary in SavedVariables
- `Sync` enables or disables evidence sharing
- `Watch`, `Ignore`, `Mark Reported`, and `Clear Reported` manage local triage state for the selected candidate
- `Clear Buffers` clears temporary unpromoted scan buffers
- `Purge Selected` deletes the selected candidate's saved evidence
- `Purge All` deletes saved candidate evidence

## Evidence and Privacy

Pattern strength is based on capped local evidence families: timing regularity, content similarity, activity/bursts, persistence, and local channel baseline outliers. Strong statuses require multiple local evidence families, and local evidence depends on local evidence volume and diversity.

Developer documentation is in [docs/DETECTION_MODEL.md](docs/DETECTION_MODEL.md), [docs/DETECTION_STRATEGY.md](docs/DETECTION_STRATEGY.md), [docs/PLAYER_METRICS.md](docs/PLAYER_METRICS.md), and [docs/DATA_EPOCHS.md](docs/DATA_EPOCHS.md).

The addon does not persist or sync raw chat text. Saved and synced data is compact: identity, observation ranges/windows, counts, timing summaries, template and shingle hashes, behavior summaries, score snapshots, baseline bins, hashed peer IDs, and version fields.

Sync does not join or create custom chat channels. When enabled, it uses hidden WoW addon-message transports for guild and group members who also run Big Bot Tracker. If no guild or group transport is available, sync waits without changing the user's chat channels.

Sync starts local-only. On first run, a notice lets you enable hidden guild/group sharing or keep the addon local; `/bbt sync on` and `/bbt sync off` can change that later.

## Commands

- `/bbt`, `/bbt open`, `/bbt show`, or `/bigbottracker` opens the report
- `/bbt status` prints tracked candidate and sync status
- `/bbt sync on` enables sync
- `/bbt sync off` disables sync
- `/bbt monitor public on|off` toggles joined public channel monitoring
- `/bbt monitor trade on|off` toggles Trade monitoring
- `/bbt monitor services on|off` toggles Services monitoring
- `/bbt export` writes a compact debug summary to `BigBotTrackerDB.settings.lastDebugSummary`
- `/bbt clear buffers` clears temporary runtime scan buffers
- `/bbt debug on`
- `/bbt debug off`

## Install

Install via CurseForge, or copy the `BigBotTracker` folder into the appropriate game client's `Interface/AddOns/` directory.

Common local install roots include `_retail_`, `_classic_`, `_classic_era_`, `_classic_tbc_` or `_anniversary_` for TBC Anniversary installs, and `_classic_titan_` for Titan Reforged.

## License

Copyright (c) 2026 Codecrete. All rights reserved.

Big Bot Tracker is proprietary software. The source is visible because World of Warcraft addons must be distributed as visible Lua code, but this project is not open source and does not grant permission to copy, modify, redistribute, rehost, sublicense, or create derivative works without prior written permission.
