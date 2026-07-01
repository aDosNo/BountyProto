# 05 — INVESTIGATION LAYER: implementation bridge

Status: BUILT, NEEDS FIRST-PERSON TUNING. Implements
`01_TRAIT_FUNNEL_MATRIX.md` (locked). Reconciled 2026-07-01 after the hybrid
scanner, authored candidate field, signature confrontation gate, chase
reacquisition path, and June 30 modular-stall integration were audited.

Numbers / scope calls marked **[NICK]** are yours.

---

## Current state (verified against live scripts 2026-07-01)

| Phase | Was | Now | Evidence |
|---|---|---|---|
| A — evidence INFORMS | fixed clue orbs routed ("go to next place") | **BUILT** — database definitions resolve against the target profile, tagged anchors vary placement, witnesses create rumors, and physical scans verify provenance-backed intel | `investigation_director.gd`, `scan_evidence_3d.gd` |
| B — tells VISIBLE | `_gait_factor()` changed locomotion speed only | `crowd_npc.gd` expresses the full KEPT vocabulary — locomotion **speed**, **dwell cadence**, **path style** (wall_hug/weave/center) — all over existing 8-dir frames | `crowd_npc.gd` `_tell_profile/_gait_factor/_dwell_pause/_path_offset` |
| C — scanner = investigation verb | raycast → dump full `build_readout` toast, 25m, free | **BUILT** — tap sweep + held analysis, cover cost, signature gate, chase reacquisition | `scanner.gd`, `bounty_manager.gd` |
| D — briefing + spatial legibility | bounty board = name + payout | HUD intel panel exists (`TARGET PROFILE`, dim/bright per trait, CONFRONT counter); dossier-on-accept still minimal | `hud.gd` `_build_intel_panel` |
| E — constructed decoy field (G7) | independent rolls | DEFERRED to generator phase; single Korvaxi contract gets a **hand-built field** (see below) | `crowd_director._deal_identities` |

**The 6/17 movement-tell ruling holds.** `vertical_bob` and `gaze_offset` are
NOT load-bearing and are NOT implemented. Earlier drafts of this doc listed them
as Phase-B work; that was wrong and is removed. Only transform-readable tells
(speed / dwell / path) are real. Do not reintroduce bob/gaze without a sprite
architecture that makes them read (overlay/redraw) — and even then the funnel
never depends on them.

---

## Why Phase C was the core gap

Previously scanning was **strictly dominant over observation**. `scanner.gd` raycast
forward; on any `scannable_npc` it calls `BountyIntel.build_readout()` and dumps
the complete per-trait answer sheet as a 4.5s toast — at up to 25m, holstered or
not, at zero cost. So there is no reason to watch the crowd for a gait, ask a
witness, or close distance: point at anyone, read everything. Phase B made tells
visible; Phase C now makes them *worth reading*.

`01` already specifies the fix in its own language: the scanner is a **terminal
gate** that reads the unique `scanner_sig` **at close range**, and "scanning
openly, or scanning the wrong NPC, costs cover." The redesign below is that
sentence, built.

---

## Phase C — the hybrid scanner (BUILT; sweep finds, analysis confirms)

Decision locked 2026-06-24 (Nick): **hybrid**. One input (`scan`, RMB) carries
two verbs by tap-vs-hold. No new input actions.

### C.1 Two verbs, one button

**SWEEP — tap RMB (a pulse).**
- Fires a forward **cone** (not a single ray): half-angle **[NICK rec: 35°]**,
  range = `sweep_range` **[NICK rec: 22m]**.
- For each `scannable_npc` and `scanner_evidence` inside the cone with LOS,
  compare its **eye-visible** traits against **currently-gathered intel**.
  - Eye-visible axes only: `appearance`, `movement_tell`, `location_habit`.
    **Never** `scanner_signature` (scanner-only) and **never** `build` (all
    candidates share it — not narrowing).
  - **Gate (locked): require ≥1 trait known.** With zero intel the sweep is
    inert — it reports "NO LEADS — gather intel first." This forces real
    investigation (witness/clue/observation) before the crowd can be filtered.
  - An NPC is **lit** if it matches on *every* visible axis the player currently
    knows (i.e. it is not yet eliminated). Knowing only "red coat" lights every
    red-coat candidate; learning "+ heavy gait" relights and the field shrinks.
- Lighting is a **world-space marker on the NPC** (a third tint state on the
  same mechanism as `_set_highlight`/`_set_scanned_tint`), held for
  `sweep_mark_duration` **[NICK rec: 6s]**, then fades. No HUD overlay needed.
- Sweep **confirms nothing** and can light decoys that happen to share the known
  visible traits. It is a *shortlist generator*, not an answer.
- **Cost: free.** It reads the crowd at large; it does not single anyone out, so
  it draws no scrutiny. This is the wide/cheap half.

**ANALYSIS — hold RMB on one NPC (close).**
- Holds the existing per-target scan against a single focused NPC, producing the
  `BountyIntel.match_report()` readout, with the **`scanner_signature` line
  resolving last** (`SIG: SCANNING…` → `[MATCH]`/`[X]`). This is the terminal
  gate: the signature is the only axis that separates the target from a perfect
  visible-trait twin (the "double").
- **Only analysis reads the signature.** Sweep never does.
- **Cost: scales with hold time AND range/blend (locked).** While analysis is
  held, the scanner emits a periodic suspicion ping at the focused NPC's
  position into the EXISTING guard perception (`gang_guard`), so "scanning
  openly costs cover" reuses the disguise/sprint machinery rather than a new
  stat. Formula in C.3.

### C.2 The intended loop

1. Learn ≥1 trait (dossier on accept, a witness one-liner, or a scanned clue).
2. **Sweep** from a vantage (balcony, plaza edge) → 10 candidates collapse to
   the few matching what you know. Free, no heat.
3. Learn more traits (more witnesses/clues/observe the gait the sweep keyed on)
   → sweep again, shortlist shrinks toward 2–3.
4. **Close in and Analyze** those few. Costs cover — do it blended, at range, or
   behind the guards' backs. Analysis confirms the signature → that's your mark.
5. Confront (accusation) per existing `BountyManager.on_npc_accused`.

Observation is now load-bearing: the movement tell the sweep filters on must
itself be *learned* (witness/vantage/binocular per `01`'s source matrix), and
analysis must be *earned* by managing cover. Sweep tells you **who to analyze**;
analysis tells you **who they are**.

### C.3 Analysis cover cost (the formula)

While ANALYSIS is held on a focused NPC, each `suspicion_tick` (every ~0.35s):

```
ping_radius = analysis_base_radius
  * (1.0 if not is_blended() else blended_factor)      # blended_factor rec 0.35
  * hold_scale                                          # ramps 1.0 -> 2.0 over analysis_time
ping at focused_npc.global_position with that radius
```

- Routed through guard perception as a sub-gunfire noise (`loudness < 25`) so it
  raises SUSPICIOUS, never instant-ALERT — a readable yellow beat, consistent
  with the rest of the perception model.
- `is_blended()` (holstered + walk pace + crowd/disguise) shrinks the ping:
  analyzing from inside a crowd is quiet; analyzing exposed in the open is loud.
- Distance falls out for free — guards only react inside the ping radius, and
  `hear_noise` already distance-checks.
- **Net:** safe to analyze the right way (blended, picking your moment); risky to
  stand in the open holding analysis on NPC after NPC. Exactly `01`'s "scanning
  openly costs cover."
- **[NICK]** `analysis_base_radius` (rec 8m), `blended_factor` (rec 0.35),
  `analysis_time` to full read (rec keep 1.5s), `hold_scale` ceiling (rec 2.0).

### C.4 Dynamic evidence folded into sweep

- Physical evidence is subtly visible without equipment and strongly highlighted
  by sweep. Evidence discovery works even with zero known visible traits; the
  intel gate applies only to NPC shortlist filtering.
- The Hesperus database currently defines footprint trails, clothing fibers,
  delivery residue, and implant coolant residue. Definitions own meaning while
  scene anchors own legal placement.
- June 30's Bazaar modular-stall replacement removed three mesh landmarks still
  named by evidence anchors. The director rejects those placements and falls
  back, so the system remains functional but placement variety is reduced.
  Current names are listed in `PROJECT_MANIFEST.md`; repair them before tuning
  evidence frequency or adding definitions.
- Witnesses record unverified rumors and point to the selected evidence zone.
  Only held analysis on the physical trace calls
  `BountyIntel.verify_from_evidence()`.
- The contract begins with one footprint trail. The non-blocking prints follow
  the anchor's authored walkable street alignment; verification then focuses
  navigation on the courtyard-side delivery trace without adding an arrow
  overlay. Delivery evidence can open the clinic-signature follow-up; witness
  leads remain parallel rather than replacing this chain.
- The HUD district navigator reports the current canonical zone plus the nearest
  active lead's compass bearing, distance, and destination zone. Player-facing
  names use `North Arcade`; `AlienBar` remains only in legacy asset identifiers.

### C.5 Scope boundary

Evidence uses contract-seeded authored anchors, not traces emitted continuously
from live NPC movement. This keeps placement valid and reproducible while still
varying each run. False witness statements and evidence aging remain deferred.

---

## Phase E (deferred) — decoy field for the single Korvaxi contract

`crowd_director._deal_identities()` still rolls each candidate independently
(only `_matches_target()` guarantees ≥1 difference). `01`'s Venn-overlap
algorithm — constructing the joint distribution so the funnel solves to exactly
`k` — stays a **generator-phase (post-sprint) task**: it needs the validator and
a difficulty dial, and building it now means debugging two systems against each
other while trying to judge scanner feel.

**For this sprint: hand-build the Korvaxi field** (this doc's decision, with
Nick's deferral). Place candidate traits by hand in
`data/crowd_traits_hesperus.json` (or a small authored candidate list) so that:
- exactly the intended shortlist survives "appearance + movement_tell +
  location_habit";
- no single visible trait isolates 1 (free giveaway);
- at least one decoy shares ALL visible traits with the target so **analysis /
  signature** is the only separator (proves the gate is doing work);
- every decoy is non-uniquely-identifiable.

This hand-built field doubles as the **manual test fixture** for the overlap
algorithm later — it's the worked example the validator must reproduce.

---

## Implementation status

- Tap sweep, held analysis, cone/LOS filtering, evidence and NPC markers, and
  guard-suspicion pings are implemented.
- The authored field narrows 5 → 3 → 1 across appearance, gait, and habit.
- Confrontation requires three known traits, scanner-signature intel, and a
  completed analysis of that subject.
- During chase, sweep can reacquire Korvaxi after his live marker is lost.
- Automated coverage: `tools/test_scanner_hybrid.gd`,
  `tools/test_dynamic_evidence_system.gd`, and
  `tools/test_golden_investigation.gd`. Remaining work is first-person evidence
  scale/readability tuning, not another scanner architecture pass.

`gang_guard.gd` is NOT modified — the scanner feeds its existing
`hear_noise`/suspicion path.

---

## Open calls reserved for Nick

1. **Sweep cone** — half-angle (rec 35°), range (rec 22m), mark duration (rec 6s).
2. **Analysis cost dials** — `analysis_base_radius` (rec 8m), `blended_factor`
   (rec 0.35), `hold_scale` ceiling (rec 2.0), analysis time (rec 1.5s).
3. **Sweep input feel** — pure tap for sweep + hold for analysis on one button,
   or a short-press threshold? (rec: press-and-release under 0.2s = sweep,
   longer = analysis; tune threshold in playtest.)
4. **Marker look** — reuse the cyan highlight hue for swept, or a distinct color
   so "swept" reads differently from "focused"? (rec: distinct — amber swept,
   cyan focused, green scanned.)

---

## One-line summary
Phases A–C shipped: clues inform, tells are visible, and the scanner is a hybrid
with a free wide **sweep** that shortlists the crowd by the
visible traits you've learned, and a cover-costing close **analysis** that reads
the signature and confirms the mark — turning the scanner from a key into the
investigation verb `01` always described.
