# Player Metrics and Wording

This file defines player-facing labels and wording. Keep the UI plain: players should know what was observed, what it means, and why the status is not higher or lower.

## Table Labels

- `Status`: player-facing evidence status.
- `Observed Signals`: compact local evidence summary.
- `Msgs`: locally observed message count.
- `Cadence`: player-friendly timing pattern.
- `Text Reuse`: percent of local messages matching the most reused normalized template.
- `Src`: `Local`, `Net`, or `L+N`.

Numeric pattern strength and local evidence percentages belong in details and tooltips, not as primary table columns.

## Status Labels

- `Peer Context Only`: peer clients shared compact evidence, but this client has no local evidence.
- `Observing`: not enough local evidence for a clear repeated pattern.
- `Early Pattern`: one local pattern exists, but evidence is limited.
- `Repeated Pattern`: repeated local behavior is clear enough to review.
- `Strong Pattern`: multiple local signals agree.
- `Very Strong Pattern`: strongest local pattern; report assist may be shown.

## Detail Labels

- `Pattern Strength`: internal 0-100 local ranking score.
- `Local Evidence`: amount and diversity of local evidence behind the current status.
- `Why This Was Flagged`: local evidence-family score details.
- `Observed Signals`: top local reasons.
- `Peer Evidence`: peer context only; never local status.

## Summary Sentence Pattern

Use this structure:

`Observed: <signals>. Meaning: <plain interpretation>. Why this status: <cap or escalation reason>.`

Examples:

- `Observed: 100% same text and dominant ~20s active-run cadence. Meaning: this repeated chat pattern is worth reviewing. Why this status: multiple local signal types agree.`
- `Observed: 3 local messages. Meaning: not enough local evidence for a clear repeated pattern yet. Why this status: too few local messages.`
- `Observed: peer clients shared compact evidence. Meaning: this is informational peer context only. Why this status: this client has no local evidence.`

## Cadence Labels

- `Fixed Cadence`: nearly every retained interval is the same bucket.
- `Dominant Active-Run Cadence`: regular active runs with gaps or outliers.
- `Jittered Cadence`: repeatable but noisy intervals.
- `Mixed Cadence`: multiple stable cadence buckets.
- `Burst Pattern`: high activity without stable cadence.

## Report Assist

Report assist is available only for `Very Strong Pattern`. Suggested text should use:

- `Repeated advertising pattern`
- `Observed timing`
- `Observed volume`
- `Repeated wording`
- `local evidence`

The addon opens Blizzard's report flow when possible, but the player must choose the category, review text, and submit manually.

## Banned Player-Facing Wording

Do not use these phrases in UI or report-assist text:

- `bot probability`
- `confirmed bot`
- `proof`

Avoid verdict language. Prefer observed-pattern language.
