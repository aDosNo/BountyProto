# 05 — INVESTIGATION LAYER: implementation bridge

Status: PROPOSAL for Nick to react to (drafted 2026-06-17, post-go/no-go).
Supersedes nothing — it implements `01_TRAIT_FUNNEL_MATRIX.md`, which is already
correct and locked. This doc is the bridge between that design and the live build,
because the **6/17 full-playability playtest revealed the build never implemented
the funnel** — it is still running the legacy linear-clue placeholder.

Numbers / scope calls marked **[NICK]** are yours.

---

## Why we paused sprites

The 6/18 go/no-go surfaced that the loop is *plumbed but not legible*. Nick's
playtest, verbatim symptoms:

1. Contract starts with no briefing — no who/why/goal, just "follow traces."
2. Clues are routing tokens — each says only "go to the next place," teaching the
   player nothing about the target.
3. Witness hints reference tells the world can't show — "the gait gives them away"
   but no NPC has a visible gait.
4. The scanner only activates clue nodes — it is a key, not an investigation tool.
5. No spatial direction — the loop is only solvable if you already know the route.

**Root cause (single):** the *intel the player gathers* and the *world they
observe* are disconnected. `01_TRAIT_FUNNEL_MATRIX.md` already designed them to be
connected (tells over existing frames, scanner-as-gate, two-stage funnel). The
build just never wired it — so what ships today is the old `clue_01 → clue_02 →
clue_03 (reveals_target)` chain, not the funnel.

This is an **implementation gap, not a design gap.** The doc below is a gap
analysis + build sequence, not a new design.

---

## Gap analysis: locked design vs. live build

| # | Design (01_TRAIT_FUNNEL_MATRIX) says | Build actually does | Gap |
|---|---|---|---|
| G1 | Clues *teach a trait* that narrows the funnel | Clues deal an `intel_value` BUT their `scan_text`/`completed_text` only say "points to the next place" | Cosmetic-ish: data is right, the *prose* routes instead of informs. Cheap fix. |
| G2 | Each narrowing trait has ≥2 in-world sources | Linear chain: clue_01→02→03, one path | Funnel is a *line*, not a *funnel*. The matrix's source-coverage table isn't built. |
| G3 | Movement tells expressed over existing frames (vertical bob = limp, gaze offset, dwell cadence, path style) | `crowd_npc.gd` `_gait_factor()` only changes *locomotion speed* for limp/fast/shuffler. No bob, no gaze, no dwell, no path style | The single most-broken thing: traits the player is *told* about are not *visible*. |
| G4 | Scanner = terminal gate; reads the unique `scanner_sig` at close range; scanning openly/wrong costs cover | `scanner.gd` toggles `scanner_clue` + `scannable_npc`; reads "PROFILE FITS"; no footprint/heat/trail reading; no cover cost | Scanner is a next-step key. The "investigation verb" doesn't exist. This is the real rework. |
| G5 | Contract briefing / dossier (the matrix references a `Dossier` source column) | Bounty board shows name + payout only; no dossier, no description, no starting trait | No briefing system at all. |
| G6 | Location habit is the strongest free narrowing axis, needs landmark legibility | `location_habit` exists in data + a clue says "courtyard," but nothing teaches *where* the courtyard is or makes the target dwell there observably | Spatial legibility missing. |
| G7 | Decoy field constructed via Venn-overlap algorithm | `crowd_director.gd` rolls each candidate's traits independently | The matrix flags this exactly: independent rolls break the funnel. Already known to be a generator-phase task — NOT this sprint. |

---

## Proposed build sequence (closes G1–G6; G7 stays deferred)

Ordered cheapest-impact-first so each step is independently playtestable and the
loop gets more legible at every stage. **Stop after any phase and re-evaluate** —
we do not need all of it to un-break the loop.

### Phase A — Make clues INFORM, not route (closes G1; ~½ day, lowest risk)
The data already deals traits. Only the *prose* and the *HUD feedback* route.
- Rewrite each clue's `scan_text`/`completed_text` so it states the **trait it
  reveals**, not the next location: e.g. clue_01 "Dock manifest flags a passenger
  in a **deep red coat**" instead of "entered the bazaar."
- When a clue is scanned, the HUD intel panel already flashes the learned trait —
  make the toast say which trait was learned ("Lead: appearance — red coat").
- **Net effect:** the player now *learns about the target* from clues, even before
  any deeper system. This alone fixes the "clues are meaningless" complaint.
- **No new systems.** Edits to clue instances + `clue_object.gd` toast text.

### Phase B — Make tells VISIBLE (closes G3; ~1–2 days, the keystone for sprites)
This is the gate on sprite work, because it defines what the sprite must express.
Implement the matrix's allowed movement expressions in `crowd_npc.gd`, all over
existing frames:
- **vertical_bob** (limp/hitch) — sinusoidal Y-offset on the billboard while
  walking; amplitude/period per tell. Reads as a limp at distance. **[NICK]**
  confirm amplitude that reads without looking silly.
- **dwell_cadence** — pause frequency/duration at waypoints (already partially
  there via `route_pause_*`; make it a per-tell identifier).
- **gaze_offset** (shifty) — yaw the billboard slightly off its travel vector.
- **path_style** — wall-hug / weave / center-cut steering bias.
- **appearance palette** — the one-time hue-isolated base mask (matrix's
  prerequisite) so `palette_id` recolors cleanly. **[NICK]** this is the first
  real sprite task and it belongs HERE, before NPC sprites.
- **Net effect:** "the gait gives them away" becomes *true* — the player can stand
  on the balcony, watch the crowd, and pick out the heavy-stepping one.

### Phase C — Scanner becomes the INVESTIGATION VERB (closes G4; the real rework, ~2–3 days)
Decision-heavy; see open calls. Two model options:
- **C-1 "Detective sweep":** RMB holds a scan cone; within it, trails/traits
  highlight — footprints tinted by recency, NPCs whose visible traits match
  current intel get a marker, the scanner-sig NPC pings only at close range.
- **C-2 "Target analysis":** aim at one NPC, hold to read a per-trait readout
  vs. gathered intel ("appearance ✓ / gait ✓ / sig: SCANNING…"), confirming or
  eliminating that candidate. Costs cover while scanning (ties to blend/guard
  scrutiny — the matrix's "scanning openly costs cover").
- Both keep the existing `scanner_clue` path for Phase-A clues. C-2 is closer to
  the locked "terminal gate" language; C-1 is flashier and more readable but more
  art/shader work.
- **[NICK]** pick C-1, C-2, or a hybrid. This is the biggest single decision.

### Phase D — Briefing + spatial legibility (closes G5, G6; ~1 day)
- **Dossier on contract accept:** a short panel — target name, portrait/placeholder,
  the bounty reason, and ONE starting trait (the matrix lists Dossier as a partial
  appearance source). Gives the player a directive and a first funnel input.
- **Landmark legibility for location habit:** make the courtyard findable —
  diegetic signage, a map ping, or an objective marker on first "courtyard" intel.
  **[NICK]** how much hand-holding — full objective marker vs. diegetic-only?
- **Net effect:** player knows who they're hunting, why, and roughly where to go.

### (Deferred) Phase E — constructed decoy field (G7)
The Venn-overlap algorithm from the matrix. **Stays a generator-phase (post-sprint)
task** — it's only needed when contracts are procedural. For the single hand-built
Korvaxi contract, place the decoy traits by hand so the funnel solves cleanly
(matrix validator rules as a manual checklist).

---

## What this does to the schedule

- 6/19–22 sprite work is **paused**, not cancelled. Phase B's palette-mask
  prerequisite is the bridge — it's a sprite task that must happen before NPC
  sprites regardless, so starting there loses nothing.
- Honest sequencing: **A → B → (decision) → C → D.** A+B alone may make the loop
  legible enough to resume sprites in parallel with C/D. We decide after B.
- Nemesis-lite, economy, contract generator all remain post-sprint and untouched.

---

## Open calls reserved for Nick (the decisions that gate the build)

1. **Scanner model (Phase C):** C-1 detective-sweep, C-2 target-analysis, or hybrid?
   *Biggest decision — everything in C flows from it.*
2. **Movement-tell amplitudes (Phase B):** how strong is "readable but not silly"
   for vertical_bob / gaze_offset? (playtest-tuned, but you set the ceiling)
3. **Palette count (Phase B):** 4–6 cleanly-separable tunic colors? (matrix's only
   art-cost number)
4. **Spatial hand-holding (Phase D):** objective marker to the courtyard, or
   diegetic-only (signage + dossier text)?
5. **Phase ordering:** do A+B then reassess, or commit to the whole A→D run now?
6. **Briefing depth (Phase D):** minimal dossier (name + reason + 1 trait) or
   richer (last-seen, faction, known associates)?

---

## One-line summary
The funnel was designed right and built wrong; this is the wiring plan to make the
investigation the player *does* match the investigation the design *describes* —
clues that inform, tells you can see, a scanner you investigate with, and a
briefing that points you in. Sprites resume once tells are visible (Phase B).
