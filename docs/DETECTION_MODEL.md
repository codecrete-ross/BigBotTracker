# Big Bot Tracker Detection Model

This is the canonical implementation-facing model for Big Bot Tracker v1. The addon observes joined public chat channels and surfaces repeated advertising evidence for player review. It does not auto-report, post public accusations, persist raw chat text, or treat peer context as local evidence.

## Data Boundaries

The addon observes `CHAT_MSG_CHANNEL` events from public channels the client already receives. It stores compact derived evidence only:

- Normalized `character-realm` identity.
- First/last seen timestamps, coarse observation windows, days seen, and channels seen.
- Bounded timing samples, interval buckets, cadence phases, and activity-window summaries.
- Normalized template hashes, shingle-signature hashes, ad-intent counters, and aggregate content counters.
- Baseline bins, score snapshots, status-cap reasons, local triage state, and compact peer evidence capsules.

Raw chat text is not persisted or synced. Peer evidence is shown separately and must not raise local status, pattern strength, local evidence, or local evidence-family count.

## Promotion

Messages first enter runtime pretrack buffers. A sender becomes a persisted candidate only after a local signal crosses a conservative threshold:

- Repeated eligible templates.
- Near-duplicate or shingle-similar ad wording.
- Enough regular timing samples.
- High volume only when paired with ad intent, low content diversity, or a mature local baseline outlier.

Message count alone is not a pattern signal. Short generic repeats below the duplicate-token threshold should remain runtime-only.

## Timing Model

Timing starts from retained inter-message intervals. Intervals outside configured min/max bounds are ignored for timing features.

Cadence labels:

- `Sparse`: too few intervals for a timing read.
- `Variable`: no stable timing pattern.
- `Burst Pattern`: activity is compact or burst-heavy without stable cadence evidence.
- `Jittered Cadence`: intervals are noisy but repeatable.
- `Dominant Active-Run Cadence`: active posting runs are regular, while full history includes gaps or outliers.
- `Mixed Cadence`: multiple stable cadence buckets appear across phases.
- `Fixed Cadence`: nearly all retained intervals are concentrated around one bucket with low rolling/global entropy and no material average-vs-median gap.

The active-run distinction is important: long idle gaps should not be hidden behind a clean median, and a candidate with multiple material interval buckets should not be labeled fixed.

## Local Evidence Families

Pattern strength is a capped local heuristic score, not a probability. It is still stored internally because it is useful for sorting and diagnostics.

- Timing: max 35.
- Content: max 30.
- Activity/bursts: max 20.
- Persistence: max 10.
- Local channel baseline: max 15.

`Dominant Active-Run Cadence` is capped below full timing maximum. Baseline evidence contributes only after at least 50 local baseline samples; it is low-weight until 200 samples.

Family-count thresholds:

- Timing >= 8.
- Content >= 8.
- Activity >= 6.
- Persistence >= 4.
- Baseline >= 5.

## Player-Facing Status

The UI leads with status, not numeric score:

- `Peer Context Only`: peers shared compact evidence, but this client has no local evidence.
- `Observing`: not enough local evidence for a clear repeated pattern.
- `Early Pattern`: one local pattern exists, but evidence is limited.
- `Repeated Pattern`: repeated local behavior is clear enough to review.
- `Strong Pattern`: multiple local signals agree.
- `Very Strong Pattern`: strongest local pattern; report assist may be shown.

Precision-first gates:

- Under 6 local messages or under 3 valid intervals: max `Observing`.
- Under 12 local messages or only 1 evidence family: max `Early Pattern`.
- `Strong Pattern` requires at least 2 local evidence families.
- `Very Strong Pattern` requires at least 3 local families, content plus timing/activity, and enough message/interval volume or multiple active runs.

Status-cap reasons must be stored and displayed when useful: too few local messages, too few timing samples, only one signal type, baseline still warming up, or peer evidence only.

## Baseline

The channel baseline compares candidates against retained local samples for the same realm/channel set. It stores bins for rate, regularity, template reuse, and bursts. It does not store raw chat text or unpromoted per-player histories.

Baseline maturity:

- `<50` samples: display `Baseline warming up`; no score contribution.
- `50-199` samples: display percentile context; low contribution cap.
- `200+` samples: full baseline contribution allowed.

## Network Evidence

Sync uses hidden guild/group addon-message transports when enabled. Capsules contain compact summaries and hashes only. Peer context may increase visibility and provide corroborating context, but it must stay visually and mathematically separate from local status and local evidence.

## Data Epoch

The player-facing evidence model uses `dataEpoch = 20260527`. Older gathered candidates, templates, baselines, peer capsules, metrics, and triage state are obsolete and wiped once on first load. Current-epoch data must survive reloads and future startups.

## Forbidden Claims

User-facing UI and report-assist text must not say:

- `bot probability`
- `confirmed bot`
- `proof`

Use observed-pattern wording: repeated advertising pattern, observed timing, reused text, local evidence, peer context, and review status.

## Source Basis

- WoW event/persistence/sync constraints: `CHAT_MSG_CHANNEL`, `SavedVariables`, and `C_ChatInfo.SendAddonMessage`.
- Behavioral bot/spam detection: multi-signal timing, content, rate, burst, and baseline agreement.
- Near-duplicate detection: token shingles, document resemblance, and compact fingerprints.

Useful references:

- https://warcraft.wiki.gg/wiki/CHAT_MSG_CHANNEL
- https://warcraft.wiki.gg/wiki/SavedVariables
- https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
- https://arxiv.org/abs/1703.03107
- https://gmagno.net/papers/ceas2010_benevenuto_twitterspam.pdf
- https://arxiv.org/abs/1703.04482
- https://arxiv.org/abs/2301.07015
