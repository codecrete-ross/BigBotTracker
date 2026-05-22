## 1.1.0

- Retail and Classic-compatible interface metadata for Retail, Mists, Cataclysm, Titan, Wrath, TBC, and Classic Era clients
- Client compatibility helper for flavor detection and UI template fallbacks on older clients
- Classic-safe hidden guild/group addon-message sync without custom chat channels; sync stays local until enabled and waits when no guild/group transport is available
- Local `Watched`, `Reported`, and `Ignored` triage states with `Active`, `All`, `Watched`, `Reported`, and `Ignored` filters
- Clearer detail-view assessment language, evidence labels, timing summaries, peer evidence wording, and report-assist status controls
- Addon logo metadata/assets plus deploy and static-test coverage for the compatibility path

## 1.0.0

- Initial release
- Trade and Services chat scanner
- Persistent promoted-candidate tracking by character-realm
- Heuristic suspicion scoring
- Rolling interval entropy and cadence phase detection
- User-facing report UI with evidence details
- Manual report assist for Critical candidates with Blizzard's in-world report flow
- Local Reported, Ignored, and Watched triage states with clean-view filters
- Hidden guild/group addon-message evidence summary sync with a first-run privacy notice
- Debug export, temporary buffer clearing, and candidate purge controls
- CurseForge packaging metadata and local deploy script
