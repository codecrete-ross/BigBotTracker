# Big Bot Tracker

Big Bot Tracker is a World of Warcraft Retail addon that helps you spot chatters who behave like automated Trade or Services advertisers.

It watches Trade and Services chat, looks for repeated timing and message patterns, and shows a ranked report with evidence for each suspicious character.

Big Bot Tracker does **not** prove that someone is botting. It does not report players, send accusations, block chat, or post anything publicly. It gives you a clear evidence report so you can decide what to do.

## What It Tracks

- Repeated Trade and Services messages
- How often a character posts
- How regular their posting interval is
- Whether their messages reuse the same template
- Whether their cadence changes between multiple regular schedules
- How long the behavior has been observed
- Whether other Big Bot Tracker users have shared matching evidence

Characters are tracked by `character-realm`, so the same name on two realms is treated as two different people.

## The Report

Open the report with `/bbt`.

The main table shows:

- Suspicion tier
- Score
- Confidence
- Character-realm
- Last seen
- Message count
- Posts per hour
- Average interval
- Template reuse
- Local/network evidence marker

Selecting a character shows more detail, including first seen, first suspected, active days, interval consistency, top interval buckets, cadence switches, near-duplicate messages, network sightings, and the top reasons behind the score.

## Scores And Confidence

The score is a bot-likelihood signal based only on chat behavior. Confidence is shown separately so a small amount of evidence does not look as strong as a long-running pattern.

Big Bot Tracker uses transparent rules, not a black-box model. Examples of evidence include:

- "Average interval 121s with very low variation."
- "80% of messages match the top template."
- "Cadence changed between stable posting schedules."
- "Seen by 3 peers in the sync channel."

## Sync And Privacy

Big Bot Tracker can share compact evidence summaries with other Big Bot Tracker users through a custom addon sync channel. Sync is enabled by default after a first-run notice and can be disabled at any time.

The sync network is not global. It only reaches players who can join the same custom channel, usually people on the same realm or connected realm.

Synced data does **not** include raw chat text by default. It sends compact evidence such as:

- Character-realm
- Observation time range
- Message count
- Timing summary
- Template hashes and counts
- Behavior summary
- Anonymous peer ID
- Addon/schema version

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
