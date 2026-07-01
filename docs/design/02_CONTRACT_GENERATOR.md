# 02 — CONTRACT GENERATOR
The orchestration layer above the trait funnel (see 01). Defines the generation
pipeline, its dependency ordering, the district descriptor that keeps it
district-agnostic, determinism, and graceful degradation. Design only — no
scene/code. **[NICK]** = your balance/product call.

Status (2026-07-01): not implemented. Hesperus has seeded dynamic evidence and an
authored candidate field, which are prototypes for S6/S7, but there is no
general `generate()` pipeline or district descriptor yet.

## What it is / isn't
- **Is:** a pure, seeded function
  `generate(seed, district_descriptor, difficulty_request, nemesis_pool) -> contract_definition`.
- **Isn't:** anything that edits scenes. It emits a **data resource**; the runtime
  crowd-populator reads it and fills NPC/source slots. This is the locked "traits
  in data files, never hardcoded in scenes" rule applied to the whole contract.
- Output feeds **BountyManager** (existing loop); trait values sync to
  **BountyIntel** (existing autoload) at populate time, exactly as the current
  hand-authored target does.

## Why seeded / pure
Reproducible contracts buy three things at zero cost: deterministic debugging
(re-run a bad contract), regression tests (assert a seed still validates), and
shareable contract seeds (a roguelike-lite nicety). Thread one seeded RNG with
named sub-streams (target / temperament / complication / decoy / sources / filler)
so a re-roll in one stage doesn't shift the others. **[NICK/product]** decision:
expose seeds to players or keep internal. Architecture supports either.

## District descriptor (the district-agnostic key)
The generator never hard-codes Hesperus. Each district ships a descriptor data
file declaring its **capacity**, and districts 2–3 drop in by authoring one — no
generator change. This is what makes "many districts × many contracts" real.
```yaml
district_descriptor:
  district_id
  crowd_capacity            # total NPC slots (~30 for Hesperus)
  candidate_capacity        # how many can share the target build (~10)
  base_classes: []          # species/build sheets available as filler (excludables)
  landmarks: []             # named, legible spots -> legal location_habit values
  source_nodes:             # finite physical slots, by type
    witness: []             # positions/NPC slots that can carry a witness line
    vantage: []             # observation points (e.g. balcony) -> direct-sight traits
    clue_spawn: []          # ClueObject anchor points -> found-clue traits
    overheard: []           # ambient-conversation slots
    broker_present: bool    # is an intel broker reachable in this district
  spawn_point
  extraction_points: []
```
The descriptor is also the **feasibility oracle**: difficulty can't exceed what
the node inventory supports (see degradation).

## Pipeline (dependency-ordered — the ordering IS the design)
Arrows mark hard dependencies; nothing may reorder past them.

**S0 · Context.** Bind `seed`, `district_descriptor`, `difficulty_request`.

**S1 · Target identity ("who").** → *(or nemesis injection, see S1′)*
- `base_id` = rolled build class (korvaxi rat-civilian for now) = the pool def.
- Target narrowing values `a_T` (palette), `m_T` (movement), `l_T` (location).
  **`l_T` constrained to district `landmarks`** — can't habit a spot that isn't
  legible here.
- `scanner_sig_T` = unique key. Alias/name for the dossier.

**S1′ · Nemesis injection (hook → doc 04).** BEFORE rolling a fresh target,
check `nemesis_pool`. An escapee re-enters here with carried + mutated traits and
a grudge. Alternate entry to S1; details deferred to 04.

**S2 · Temperament.** on-detect reaction (flee/fight/bribe/freeze). **Rolled
independently of `m_T`** (matrix rule — else temperament leaks identity). Affects
endgame, not the funnel.

**S3 · Contract type.** alive vs dead; **alive = 2× pay** and *requires* a
non-lethal capture verb (net/stun). alive + `fight` temperament = harder → feeds
the risk premium in S8.

**S4 · Complication.** rival / double / bribed_faction / curfew.
**Must precede S6** because **`double` reparametrizes the decoy stage** (forces a
perfect twin). The others are orthogonal modifiers: rival = +1 competing AI actor
+ time pressure; bribed_faction = guard-scrutiny modifier; curfew = thinner crowd
(blending harder) + movement constraint.

→ **S5 · Difficulty resolution.** `difficulty_request` (+ `double` if rolled)
resolves to decoy params `k, n_a, n_m, n_l` (defined in 01). **[NICK]** owns the
D→params curve.

→ **S6 · Decoy-field construction.** Run the overlap algorithm (01) to build the
**9 decoys** around the target = 10-strong candidate pool sharing `base_id`.
Search space is tiny (3 axes, ~4–6 palette values, 9 decoys) → **backtracking /
brute force, no solver needed.** Validate (01's asserts). On fail, re-roll the
**decoy sub-stream only**, retry budget ~16, then degrade (S-degrade).

**S6b · Crowd filler.** Fill remaining `crowd_capacity − 10` slots (~20) with
excludables: random non-target `base_classes`, irrelevant traits. Cheap, lightly
seeded. These are the funnel's noise floor.

→ **S7 · Source placement (constraint-satisfaction).** For each narrowing trait
`a_T/m_T/l_T`, bind its value into **≥2 physical `source_nodes`**, respecting:
(a) the source-type×trait legality from 01's matrix (e.g. movement never from
dossier; location can come from witness/overheard/clue); (b) finite node counts in
the descriptor. Dossier always seeded with stale/partial appearance + alias +
scanner-sig *type hint*. If the broker is present, register one purchasable
trait-reveal. Fail → re-roll source sub-stream → degrade.

→ **S8 · Economy resolution (hook → doc 03).** `payout = base · type_mult(2× alive)
· f(difficulty) · risk_premium(complication, temperament)`. Optional staked bond
offer. Generator only owns the **formula slots**; numbers live in 03.

**S9 · Emit `contract_definition`.** Abstract, scene-free: the 10 candidate
trait_kits + ~20 filler + source bindings + spawn/extraction + payout + flags.
Runtime crowd-populator consumes it; BountyIntel gets `scanner_sig_T` +
intended_solution.

## Graceful degradation (don't hard-fail)
If the district descriptor can't support the request (e.g. not enough `vantage` +
`witness` nodes to give movement its 2 sources, or `candidate_capacity` too low
for `k`), **clamp, don't crash**: lower `k`/`n_*` toward what the node inventory
allows, drop the weakest narrowing axis to 1 source as a last resort (flag it), and
if `double` is impossible here, swap complication. Always emit *a* valid contract;
log what was clamped. This keeps small/early districts shippable.

## contract_definition (emitted shape)
```yaml
contract_definition:
  seed; district_id
  target:
    base_id; alias
    appearance: { palette_id, overlay_ids: [] }
    movement_tell_id; location_habit_id
    scanner_sig
    temperament: { on_detect }
  candidate_pool: [trait_kit, ...]      # 10 incl. target (from S6)
  crowd_filler:   [trait_kit, ...]      # ~20 excludables (S6b)
  intended_solution: { a_T, m_T, l_T }  # funnel answer (for BountyIntel/validation)
  source_bindings:                       # S7 output
    - { trait, value, source_type, node_ref }
  type: alive | dead
  complication: rival | double | bribed_faction | curfew | none
  difficulty: { D, k, n_a, n_m, n_l, clamped: [] }
  payout: { base, type_mult, diff_mult, risk_premium, bond_offer }
  spawn_point; extraction_points: []
```

## Build order when it's time to implement (post-sprint)
1. District descriptor schema + author Hesperus's (read real node positions from
   the `.tscn` — use the tagged
   `Gameplay/Investigation/EvidenceAnchors`, not the removed fixed ClueObject
   chain; include legal witness, evidence, vantage, and extraction slots).
2. S6 decoy algorithm + validator in isolation (unit-testable, no scene).
3. S7 source placement against the descriptor.
4. S1–S5/S8 sampling wrappers (cheap once 2–3 exist).
5. Runtime crowd-populator that turns `contract_definition` into spawned NPCs +
   bound sources (this is the only scene-touching part, and it's generic).
6. Nemesis (04) and economy numbers (03) layer on after the loop runs.

## Open calls reserved for Nick
- D → (k, n_a, n_m, n_l) curve (shared with 01).
- Contract-type / complication **roll weights** (how often alive? how often double?).
- Seeds exposed to players? (product).
- Does `rival` (competing AI hunter) ship in the generator v1 or get stubbed as a
  flag until the chase AI supports a second agent? (It leans on 6/13–14 chase work.)
