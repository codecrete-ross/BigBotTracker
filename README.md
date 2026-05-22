# Big Bot Tracker

Big Bot Tracker is a World of Warcraft Retail addon that helps you spot chatters who behave like automated Trade or Services advertisers.

It watches Trade and Services chat, looks for repeated timing and message patterns, and shows a ranked report with evidence for each suspicious character.

Big Bot Tracker does **not** prove that someone is botting. It does not report players, send accusations, block chat, or post anything publicly. It gives you a clear evidence report so you can decide what to do.

## What It Tracks

- Repeated Trade and Services messages
- How often a character posts
- How regular their posting interval is
- Whether their messages reuse the same template
- Whether similar ads cluster even when words are rearranged
- Whether their cadence changes between multiple regular schedules
- Whether their behavior is unusual compared with the current monitored channel
- How long the behavior has been observed
- Whether other Big Bot Tracker users have shared matching evidence

Characters are tracked by `character-realm`, so the same name on two realms is treated as two different people.

## The Report

Open the report with `/bbt`.

The main table shows:

- Character-realm
- Suspicion tier
- Score
- Confidence
- First seen
- Last seen
- Message count
- Posts per hour
- Average interval
- Cadence
- Template reuse
- Local/network evidence marker

Selecting a character shows more detail, including first seen, first suspected, active days, interval consistency, top interval buckets, robust timing variation, cadence switches, near-duplicate messages, evidence-family scores, current-channel baseline comparison, network sightings, network overlap context, and the top reasons behind the score.

## Scores And Confidence

The score is a bot-likelihood signal based only on local chat behavior. Confidence is shown separately so a small amount of evidence does not look as strong as a long-running pattern.

Big Bot Tracker uses transparent rules, not a black-box model. V1 scoring is grouped into capped evidence families:

- Timing regularity
- Content similarity
- Activity and burst behavior
- Persistence across time
- Current-channel baseline outliers

High and Critical tiers require multiple local evidence families. A single signal, such as template reuse alone or peer sightings alone, should not make someone look like a strong suspect.

Examples of evidence include:

- "Median interval 121s with very low robust variation."
- "80% of messages match the top template."
- "Similar ad wording clusters even when text is rearranged."
- "Cadence changed between stable posting schedules."
- "Timing is more regular than 95% of monitored advertisers."

## Sync And Privacy

Big Bot Tracker can share compact evidence summaries with other Big Bot Tracker users through a custom addon sync channel. Sync is enabled by default after a first-run notice and can be disabled at any time.

The sync network is not global. It only reaches players who can join the same custom channel, usually people on the same realm or connected realm.

Synced data does **not** include raw chat text by default. It sends compact evidence such as:

- Character-realm
- Observation time range
- Coarse observation windows
- Message count
- Timing summary
- Template hashes and counts
- Shingle cluster hashes and counts
- Behavior summary
- Anonymous peer ID
- Addon/schema/feature version

Network evidence is context only. It does not increase the local score or local confidence because peers may be seeing the same public chat messages.

## Commands

- `/bbt` opens the report
- `/bbt status` prints tracked candidate and sync status
- `/bbt sync on` enables sync
- `/bbt sync off` disables sync
- `/bbt channel NAME` changes the custom sync channel
- `/bbt monitor trade on|off` toggles Trade monitoring
- `/bbt monitor services on|off` toggles Services monitoring
- `/bbt export` writes a compact debug summary to `BigBotTrackerDB.settings.lastDebugSummary`
- `/bbt clear session` clears temporary scan buffers
- `/bbt debug on`
- `/bbt debug off`

## Future ML Option

Machine learning is not implemented in v1.

WoW addons cannot train models in-game or call external ML services during play. A future ML feature would need to be trained outside the game from exported feature summaries, not raw synced chat logs.

If added later, a trained model would ship as small Lua data or code in an addon update. It could help calibrate scoring weights, but the addon should still show visible evidence reasons and avoid black-box accusations.

## Install

Install via CurseForge, or copy the `BigBotTracker` folder into your `_retail_/Interface/AddOns/` directory.

## License

Copyright (c) 2026 Codecrete. All rights reserved.

Big Bot Tracker is proprietary software. The source is visible because World of Warcraft addons must be distributed as visible Lua code, but this project is not open source and does not grant permission to copy, modify, redistribute, rehost, sublicense, or create derivative works without prior written permission.
