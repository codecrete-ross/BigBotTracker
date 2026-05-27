# Data Epochs

Data epochs mark breaking evidence-model changes. They are separate from schema versions.

## Current Epoch

`CURRENT_DATA_EPOCH = 20260527`

Reason: `player-facing-detection-cutover`

This epoch starts fresh for the player-facing evidence model. Previously gathered candidates, templates, baselines, peer capsules, metrics, score snapshots, debug summaries, and triage state are obsolete.

## Reset Rules

On startup:

- Missing DB: create a fresh DB with the current epoch and no reset history.
- Missing or old `dataEpoch`: perform a one-time evidence cutover.
- Current `dataEpoch`: never wipe gathered evidence.

The one-time cutover clears evidence tables and runtime buffers, then writes the current epoch before new evidence can be collected.

## Wiped Data

- `candidates`
- `templates`
- `baselines`
- `peers`
- candidate score snapshots
- candidate triage state
- peer capsules
- debug summaries
- runtime pretrack, recent-normalized, seen-line, and baseline cooldown buffers

## Preserved Preferences

- debug enabled/disabled
- sync enabled/disabled
- sync guild/group transport choices
- monitor toggles
- valid UI sort/filter choices

Do not preserve watched, reported, or ignored state across an epoch reset because those states belong to obsolete candidates.

## Reset History

Store a bounded `resetHistory` record with:

- previous schema version
- previous feature version
- previous data epoch
- reset timestamp
- current data epoch
- reset reason

Keep at most two records.

## Future Epoch Changes

Create a new epoch only when old gathered evidence could be misleading under the new model. Do not use epochs for ordinary code fixes, UI label changes, or additive fields that can safely default.
