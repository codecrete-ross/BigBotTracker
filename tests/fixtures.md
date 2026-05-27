# Big Bot Tracker Test Fixtures

Use these cases for manual or Lua-harness testing.

## Casual Human

- One or two joined public channel messages in a session
- Expected: remains session-only, not persisted

## Macro Advertiser

- Three similar messages within 30 minutes
- Intervals vary substantially
- Expected: promoted as `Observing` or `Early Pattern` depending on template reuse

## Fixed Cadence

- Ten messages with intervals near 120 seconds
- Same or near-same template
- Expected: low rolling entropy and dominant `~120s` bucket, but not above `Early Pattern` until enough local evidence accumulates

## Dominant Active-Run Cadence With Gaps

- Multiple active runs at the same interval, with occasional long gaps or outlier intervals
- Same or near-same template
- Expected: promoted as strong timing evidence, but cadence label is `Dominant Active-Run Cadence`, not `Fixed Cadence`

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
- Expected: network-only candidate can appear as `Peer Context Only`, but peer context cannot raise local status, pattern strength, or local evidence
