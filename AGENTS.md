# AGENTS.md

This is the canonical shared governance file for repository-level agent guidance.

## What This Is

Big Bot Tracker is a World of Warcraft Retail addon that monitors Trade and Services chat and surfaces chat-based bot-likelihood reports. It tracks suspicious advertising patterns, not confirmed botting.

## Project Structure

- `BigBotTracker.toc` - addon metadata and load order
- `Util.lua` - shared helpers
- `Normalizer.lua` - message normalization, hashing, similarity
- `Scoring.lua` - interval entropy, cadence detection, score calculation
- `Storage.lua` - SavedVariables schema and candidate persistence
- `ChatScanner.lua` - `CHAT_MSG_CHANNEL` intake and promotion thresholds
- `Sync.lua` - addon-message evidence capsule sync
- `UI.lua` - report window and controls
- `Core.lua` - events, slash commands, startup
- `scripts/deploy.ps1` - local copy deploy to Retail AddOns folder
- `.pkgmeta` - CurseForge packager config

## Core Rules

- Retail only.
- Do not auto-report players.
- Do not post public accusations.
- Use suspicion/evidence language, not confirmed-bot language.
- Do not sync raw chat text by default.
- Keep local evidence and network evidence visually separate.
- Key tracked chatters by normalized `character-realm`.
- Prefer standalone Lua with no external dependencies unless sync throttling later requires a small proven library.

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
3. Test in-game with `/reload` and `/bbt`.
4. Wait for user confirmation before committing, tagging, pushing, or releasing.

