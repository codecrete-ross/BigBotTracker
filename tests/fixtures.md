# Big Bot Tracker Test Fixtures

Use these cases for manual or Lua-harness testing.

## Casual Human

- One or two Trade/Services messages in a session
- Expected: remains session-only, not persisted

## Macro Advertiser

- Three similar messages within 30 minutes
- Intervals vary substantially
- Expected: promoted, low/medium score depending on template reuse

## Fixed Cadence

- Ten messages with intervals near 120 seconds
- Same or near-same template
- Expected: high score, low rolling entropy, dominant `~120s` bucket

## Schedule Switch

- Six messages near 120-second intervals
- Then six messages near 180-second intervals
- Expected: cadence phases show both intervals, cadence switch count > 0

## Realm Separation

- `Example-Area52`
- `Example-Illidan`
- Expected: two separate candidate records

## Peer Poisoning Guard

- One peer sends evidence for a candidate with no local observations
- Expected: network-only candidate can appear, but one peer cannot dominate score alone
