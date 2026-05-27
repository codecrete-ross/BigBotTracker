# Detection Strategy

Big Bot Tracker is precision-first. It should show fewer alarming statuses rather than overstate weak evidence. The addon is a player tool, so the output must be understandable without knowing the scoring internals.

## Strategy

- Use multi-signal agreement. Timing, content, activity, persistence, and baseline evidence are weak alone and stronger together.
- Treat repeated text plus regular active-run timing as the core local pattern.
- Treat high volume as contextual unless paired with ad intent, low content diversity, or a mature baseline outlier.
- Treat peer context as corroboration only. Peer clients can observe the same public messages, so peer context cannot raise local status.
- Prefer status caps over dramatic escalation when evidence is immature.

## Research Basis

Leading bot and spam systems combine behavioral, temporal, and content signals rather than relying on a single metric. Game-bot work also supports low-entropy behavior and repeated action patterns, but player-facing tools must avoid overclaiming certainty. Social spam research supports near-duplicate text and campaign similarity, while benchmark research warns that bot labels often fail to generalize.

References tracked by the project:

- Varol et al., Online Human-Bot Interactions: Detection, Estimation, and Characterization: https://arxiv.org/abs/1703.03107
- Benevenuto et al., Detecting Spammers on Twitter: https://gmagno.net/papers/ceas2010_benevenuto_twitterspam.pdf
- Cresci et al., Social Fingerprinting: https://arxiv.org/abs/1703.04482
- Hays et al., Simplistic Collection and Labeling Practices: https://arxiv.org/abs/2301.07015

## False Positive Risks

- Human macro advertisers can reuse text without automation.
- Busy channels can make short-window rates look extreme.
- Long idle gaps can make active-run cadence look more fixed than full-history behavior.
- Baselines are biased until enough local samples exist.
- Peer context can amplify visibility without adding independent local evidence.

## Calibration Rules

- Fixture tests must cover both false-positive and true-pattern examples.
- Threshold changes must update `docs/DETECTION_MODEL.md`.
- UI wording changes must update `docs/PLAYER_METRICS.md`.
- Breaking evidence semantics require a new data epoch and an entry in `docs/DATA_EPOCHS.md`.
- Future ML must be offline-trained from exported feature summaries, never in-game or from synced raw chat.
