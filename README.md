# Big Bot Tracker

<p align="center">
  <img src="logo.png" alt="Big Bot Tracker logo" width="320" />
</p>

Big Bot Tracker is a World of Warcraft Retail addon that monitors Trade and Services chat for suspicious repeated advertising patterns.

It does **not** prove that someone is botting. It does not auto-report players, post accusations, block chat, or send public messages. It shows evidence so you can review the pattern yourself.

## What It Does

- Watches Trade and Services chat, ignoring your own messages
- Tracks chatters by normalized `character-realm`
- Promotes local candidates only after signals such as repeated templates, near-duplicate wording, regular timing, or high volume with ad-like behavior
- Shows timing, content reuse, activity, persistence, current-channel baseline, and network context
- Keeps local evidence and network evidence separate
- Uses transparent heuristic scoring, not machine learning or external services

Message count alone is not treated as suspicion. Network sync can create `Preliminary` network-only entries, but peer evidence does not raise a local score, confidence, or tier.

## Report Window

Open the report with `/bbt`, `/bbt open`, `/bbt show`, `/bigbottracker`, or the addon compartment button.

The table shows character-realm, tier, score, confidence, first/last seen, message count, posts per hour, average interval, cadence, template reuse, and source: `Local`, `Net`, or `L+N`.

Selecting a row shows detail sections for summary, activity, timing, content, evidence families, current-channel baseline, network context, and top evidence reasons. Click headers to sort and hover rows or headers for field explanations.

Critical candidates show a `Report` button. It opens Big Bot Tracker's report assist and tries to open Blizzard's in-world report flow when a reportable player location is available. You must choose the Blizzard category, review or paste any text, and submit manually.

Other report controls:

- `Refresh` rebuilds the visible report
- `Export` saves a compact debug summary in SavedVariables
- `Sync` enables or disables evidence sharing
- `Clear Buffers` clears temporary unpromoted scan buffers
- `Purge Selected` deletes the selected candidate's saved evidence
- `Purge All` deletes saved candidate evidence

## Scores and Privacy

Local scores are based on capped evidence families: timing regularity, content similarity, activity/bursts, persistence, and current-channel baseline outliers. High and Critical tiers require multiple local evidence families, and confidence depends on local evidence volume and diversity.

The addon does not persist or sync raw chat text. Saved and synced data is compact: identity, observation ranges/windows, counts, timing summaries, template and shingle hashes, behavior summaries, score snapshots, baseline bins, hashed peer IDs, and version fields.

Sync does not join or create custom chat channels. When enabled, it uses hidden WoW addon-message transports for guild and group members who also run Big Bot Tracker. If no guild or group transport is available, sync waits without changing the user's chat channels.

## Commands

- `/bbt`, `/bbt open`, `/bbt show`, or `/bigbottracker` opens the report
- `/bbt status` prints tracked candidate and sync status
- `/bbt sync on` enables sync
- `/bbt sync off` disables sync
- `/bbt monitor trade on|off` toggles Trade monitoring
- `/bbt monitor services on|off` toggles Services monitoring
- `/bbt export` writes a compact debug summary to `BigBotTrackerDB.settings.lastDebugSummary`
- `/bbt clear buffers` clears temporary runtime scan buffers
- `/bbt debug on`
- `/bbt debug off`

## Install

Install via CurseForge, or copy the `BigBotTracker` folder into your `_retail_/Interface/AddOns/` directory.

## License

Copyright (c) 2026 Codecrete. All rights reserved.

Big Bot Tracker is proprietary software. The source is visible because World of Warcraft addons must be distributed as visible Lua code, but this project is not open source and does not grant permission to copy, modify, redistribute, rehost, sublicense, or create derivative works without prior written permission.
