# 01 — TRAIT FUNNEL MATRIX
Feeds the contract generator. Records the trait model, the source coverage rule,
the decoy-field construction algorithm, and the data shapes. Design only — no
scene/code yet. Mobile-reviewable; numbers marked **[NICK]** are layout/balance
calls reserved for you.

## Locked architecture decision (appearance)
**C now, B later.** Appearance is palette-only at first: shared base sheet +
`palette_id`. Schema carries an empty `overlay_ids[]` so architecture B
(directional accessory overlays) is purely additive later — no generator,
algorithm, or save-format change when it lands.
- One-time prerequisite (art, yours): re-author the civilian base with a
  **hue-isolated palette mask** so runtime recolor doesn't smear the way the
  teal-from-sand derivation did. This is the first sprite task back at desk.
- Per-appearance-value art cost after that: **zero**.

## Two filters, not one (critical distinction)
The funnel has two stages with different jobs:
1. **Crowd → candidates** (coarse, ~30 → ~10): shared **build/species class**
   (korvaxi rat-civilian base). This is the *pool definition* — what makes an
   NPC "could be the target." `base_id` is constant across all candidates in a
   contract. NOT a narrowing trait.
2. **Candidates → target** (fine, ~10 → 1): the narrowing traits below +
   the scanner gate, operating *within* the shared-build pool. This matches the
   locked "same build, differ in ≥1 trait."

## Trait axes
| Axis | Category | Rendered as | Narrowing strength | New art? |
|---|---|---|---|---|
| Appearance (tunic palette) | VISUAL | `palette_id` → base recolor | Medium; **never identifies alone** (shared by design) | One-time base mask only |
| Movement tell | behavior, ambient | transform/nav over EXISTING frames | **Weakest** — may not read at crowd distance; usually needs corroboration | **None** |
| Location habit | behavior, schedule | waypoint / dwell / avoid | **Strongest free axis** (needs landmark legibility) | **None** |
| Scanner signature | verification GATE | scanner-UI only; invisible to eye | Terminal — confirms, doesn't narrow | **None** |

**Movement tell — allowed expressions** (all over existing 8-dir frames).
RULED 2026-06-17 (Nick, playtest reasoning): a flat billboard can only fake
movement via TRANSFORM, and not all transforms read at crowd distance. KEEP the
ones that communicate — **locomotion speed, dwell/pause cadence at waypoints,
path style (wall-hug / weave / center-cut)**. DROP as load-bearing tells
**vertical bob (limp/hitch)** and **gaze offset (shifty)** — on a flat billboard
these read as rendering wobble, not character, and would need redrawn poses to
actually land (which is forbidden). They may return as pure flavor if a future
sprite architecture (overlays / redrawn frames) makes them read, but the funnel
NEVER depends on them. **FORBIDDEN: anything needing redrawn frames** — that
converts a free axis into an art axis.

## Source coverage matrix (2+ real sources per narrowing trait)
Funnel rule: each narrowing trait obtainable from ≥2 sources so no single source
is a chokepoint. Scanner sig is excluded — it's the gate, see below.

| Narrowing trait | Dossier | Witness | Overheard | Vantage/observe | Binocular tag | Found clue | Intel broker |
|---|---|---|---|---|---|---|---|
| Appearance (palette) | partial/stale | ✓ | ✓ | ✓ (direct sight) | ✓ | — | ✓ (paid) |
| Movement tell | — | ✓ | — | ✓ (built: balcony limp clue) | ✓ | — | ✓ (paid) |
| Location habit | — | ✓ | ✓ | — | — | ✓ (residue/receipts) | ✓ (paid) |

Notes: appearance is over-sourced because it's visible — fine, since visible ≠
identifying when shared across decoys. Movement leans on witness + vantage +
binocular; because it reads weakly, treat it as *corroborating*, rarely
sole-narrowing. Intel broker can pre-reveal **one** trait (economy sink) — it's a
paid shortcut into any row, not a unique source.

## Scanner signature = terminal gate (not trait #4)
Every target carries a **unique** scanner key; decoys carry their own non-matching
keys. The eye can't see it; only the scanner reads it, at close range. The entire
point of the narrowing axes is to get you close enough to the *right* candidate to
risk a scan — because scanning openly, or scanning the wrong NPC, costs cover
(ties into blending/guard scrutiny). The *hint that a sig exists / which kind to
look for* may come from dossier or broker; **confirmation is always the scan.**

## Decoy-field overlap algorithm (THE missing piece)
Funnel difficulty is a property of the **joint distribution** of traits across the
pool, which must be **constructed, not rolled per-NPC.** Independent per-candidate
rolls break the funnel both ways: sometimes the target is the only teal+limping NPC
(scanner pointless, accusation risk-free); sometimes five share everything (funnel
stalls). So the generator needs an explicit overlap-sizing step.

Model = **Venn-region sizing** over the 3 narrowing axes (appearance a, movement m,
location l):
1. Roll target values `a_T, m_T, l_T` + unique `scanner_sig_T`.
2. Pick difficulty dial **D** → final triple-overlap size `k` (target + (k−1)
   near-twins surviving all 3 traits). **[NICK]** default k.
3. Pick single-trait match counts `n_a, n_m, n_l` (how many candidates share each
   value with the target — i.e. "this trait alone narrows to X"). **[NICK]** these.
4. Assign decoy trait values so: exactly `n_a−1` decoys get `a_T` (etc.), arranged
   so the triple intersection `a_T ∧ m_T ∧ l_T` = exactly `k`. Distribute the
   remaining (non-matching) values so no *unintended* trait-conjunction isolates a
   smaller unique set than the intended solution.
5. **Validate (assert before emitting contract):**
   - full conjunction isolates exactly `k`;
   - no *single* narrowing trait isolates 1 (that's a free giveaway);
   - ≥2 in-level sources exist for each of `a_T, m_T, l_T`;
   - every decoy is itself non-uniquely-identifiable (no decoy accidentally looks
     "more like the wanted poster" than the target).

**Duty-doubling insight:** the **"double" complication is this same routine with
`k≥2` forced and the twin sharing ALL narrowing traits** (only the scanner
separates them), plus a diegetic reason for the twin (rival hunter / hired decoy).
Funnel difficulty and the "double" are one mechanism at different dial settings —
build the overlap step once.

## Temperament vs ambient tell — independent rolls
- **Temperament** = reaction profile on *detection* (flee / fight / bribe / freeze).
- **Movement tell** = ambient identifying behavior while *undetected* (axis above).
- These MUST roll independently. If "nervous" temperament always implied a shifty
  gaze tell, temperament would leak the target's identity for free. Separate
  sections of the behavior profile, no forced correlation.

## Data shapes (C-now, B-later)
```yaml
trait_kit:               # generator assigns one per candidate
  base_id                # POOL-LEVEL: shared by all candidates in a contract
  appearance:
    palette_id           # within-pool narrowing trait (tunic color)
    overlay_ids: []      # architecture B; empty under C
  movement_tell_id       # -> behavior_profile.movement_tell
  location_habit_id      # -> waypoint/dwell/avoid set
  scanner_sig            # unique for target; decoys get own non-matching sigs

behavior_profile:        # data file, referenced not inlined
  movement_tell:         # ambient, undetected
    locomotion_speed     # KEPT (6/17): reads at distance
    dwell_cadence        # KEPT (6/17): reads at distance
    path_style           # KEPT (6/17): wall_hug | weave | center
    # vertical_bob / gaze_offset DROPPED as load-bearing (6/17) — don't read on
    # a flat billboard; reserved for a future overlay/redraw sprite arch only.
  temperament:           # reaction, on-detect — INDEPENDENT of movement_tell
    on_detect            # flee | fight | bribe | freeze

contract:                # generator emits
  target_ref
  candidate_pool: [trait_kit, ...]    # built by decoy-overlap algorithm
  intended_solution: {a_T, m_T, l_T}  # the funnel answer
  scanner_sig_T
  difficulty_dial                     # D -> k, n_a, n_m, n_l
  complication                        # rival | double | bribed_faction | curfew
```

## Open calls reserved for Nick
- **Palette count**: how many cleanly-separable tunic colors? (rec: 4–6; small on
  purpose so appearance can't solo-identify). This is the only number that costs
  art time.
- **k** (near-twins surviving all traits): default difficulty.
- **n_a / n_m / n_l** (single-trait narrow counts): the felt difficulty curve.
- Whether movement tells get a corroboration *requirement* (can't be sole-narrowing)
  baked into the validator, given they read weakly at crowd distance.
