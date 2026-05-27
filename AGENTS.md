# AGENTS.md

This is the canonical shared governance file for repository-level agent guidance.

## What This Is

Big Bot Tracker is a World of Warcraft Retail and Classic addon that monitors joined public chat channels and surfaces player-facing evidence for repeated advertising patterns. It tracks observed chat patterns, not confirmed botting.

## Project Structure

- `BigBotTracker.toc` - addon metadata and load order
- `Util.lua` - shared helpers
- `Compat.lua` - client flavor detection and UI compatibility helpers
- `Normalizer.lua` - message normalization, hashing, similarity
- `Scoring.lua` - interval entropy, cadence detection, score calculation
- `Storage.lua` - SavedVariables schema and candidate persistence
- `ChatScanner.lua` - `CHAT_MSG_CHANNEL` intake and promotion thresholds
- `Sync.lua` - addon-message evidence capsule sync
- `Report.lua` - report assist text and Blizzard report-flow helpers
- `UI.lua` - report window and controls
- `Core.lua` - events, slash commands, startup
- `docs/DETECTION_MODEL.md` - canonical v1 detection model and status semantics
- `docs/DETECTION_STRATEGY.md` - detection strategy, research basis, and calibration posture
- `docs/PLAYER_METRICS.md` - player-facing labels, tooltips, summaries, and report-assist wording
- `docs/DATA_EPOCHS.md` - evidence reset policy and data epoch rules
- `scripts/deploy.ps1` - local copy deploy to the configured WoW AddOns folder
- `.pkgmeta` - CurseForge packager config

## Core Rules

- Retail and Classic clients only; do not target private servers or unsupported addon environments.
- Do not auto-report players.
- Do not post public accusations.
- Use suspicion/evidence language, not confirmed-bot language.
- Do not sync raw chat text by default.
- Keep local evidence and network evidence visually separate.
- Key tracked chatters by normalized `character-realm`.
- Keep Big Bot Tracker proprietary and all rights reserved. Do not add an open-source license.
- Prefer standalone Lua with no external dependencies unless sync throttling later requires a small proven library.

## V1 Detection Model

V1 is non-ML and explainable. It uses capped local evidence families: timing regularity, content similarity, activity/burst behavior, persistence, and current-channel baseline outlier comparison.

Strong player-facing statuses require multiple local evidence families. Network evidence must not boost local status, pattern strength, or local evidence because peer clients may observe the same public messages.

Feature storage must remain compact. Do not persist raw chat text. Store bounded interval samples, template hashes, shingle hashes, category counters, coarse observation windows, aggregate baseline bins, and score snapshots.

Promotion should stay conservative. Message count alone is not suspicion; promotion requires repeated templates, near-duplicate/shingle clusters, regular timing, or high volume paired with ad intent, low content diversity, or baseline outlier evidence.

## Future ML

Do not implement ML in v1.

WoW addons cannot train models in-game or call external ML services during play. A future ML path must be offline-trained from exported feature summaries, not raw synced chat logs. If added later, the model should be tiny Lua data/code, such as logistic regression weights, a small decision tree, or a calibrated scoring table.

ML may calibrate the heuristic score, but it must not replace visible evidence reasons or produce black-box accusations. The UI must continue to show timing, template, persistence, and local/network evidence.

Development order:

1. v1 heuristic scoring and feature collection
2. optional anonymized feature-summary export
3. offline training outside WoW
4. reviewed tiny Lua model only if accuracy improves and explanations remain clear

## Development Workflow

1. Edit source files in this repo.
2. Deploy locally with:
   `powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1`
3. Test in-game with `/reload` and `/bbt` in the target supported client.
4. Wait for user confirmation before committing, tagging, pushing, or releasing.
