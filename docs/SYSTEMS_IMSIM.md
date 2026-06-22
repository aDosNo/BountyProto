# bounty-hunt — Im-Sim Systems Contract

The im-sim promise is consistency: every verb works the same way on every object
that plausibly affords it, and the world reacts whether or not the player is the
cause. This matrix is the single place rules get decided. When implementing any
prop, NPC, or interaction, wire it against this table; if a cell is blank,
propose a ruling to Nick — do not improvise one silently.

Status legend: ✔ implemented · R = ruled (designed, not built) · ? = needs ruling

## Target identity model (PHASE: single scripted bounty — Option B, 2026-06-13)

The funnel's correct answer is the SCRIPTED COURTYARD KORVAXI, not a rolled crowd
NPC. `data/crowd_traits_hesperus.json` carries `target_in_crowd: false` and a
`funnel_profile` = Korvaxi's sprite-derived traits (build korvaxi-class heavy /
appearance red coat / movement_tell heavy gait / location_habit courtyard /
scanner_signature cybernetic arm). CrowdDirector stamps `target_profile` from
that profile (so clues + witness hints narrow toward HIM) but spawns NO is_target
crowd NPC — the crowd is pure candidates + civilians. `korvaxi_target.gd` now
carries the trait fields + the scanner/confront contract and joins `scannable_npc`
while hidden; scanning him reads PROFILE FITS against gathered intel, confronting
him is the accusation (`on_npc_accused` checks his `is_target`). On reveal he
leaves `scannable_npc` so the scanner can't re-acquire him mid-chase.
GENERATOR PHASE: set `target_in_crowd: true` (or drop the keys) and the director
rolls a hidden-in-crowd target again; `resolve_as_target_handoff()` bridges that
crowd actor to the chase. WRONG-ACCUSATION SPOOK (RULED 2026-06-17, Nick): under
Option B `crowd_director.spook_target()` no-ops because `target_npc` is null —
verified null-safe (BountyManager guards the call; the director guards the method),
so a wrong mark is NOT a crash. Decision: LEAVE AS-IS for the sprint. On a wrong
accusation Korvaxi does NOT relocate; the consequence is guard-alert (nearby
`perceptive` guards via `on_ally_alert`) + district heat only. Making Korvaxi
relocate needs a hidden-state reposition/patrol path on what is currently a static
courtyard model — that is chase-AI work belonging to the generator phase (when
`target_in_crowd` flips and the crowd actor handoff exists). Re-flagged there, not
a bug to fix now.

## Verb × Object matrix

| Verb ↓ / Object → | Korvaxi (target) | GangGuard | Civilian sprite NPC | Witness | Locked door (Z6 back door) | Grate / vent | Ladder / balcony | Bounty board |
|---|---|---|---|---|---|---|---|---|
| **Stun net** (capture verb) | ✔ captures, alive payout | ? (R-proposal: stuns N sec, no bounty) | ? (R-proposal: stuns, crowd panics, heat+) | ? | — | — | — | — |
| **Lethal fire** | ✔ kills, dead payout + heat | ✔ kills | ✔ wounds/kills, heat++, crowd panic, vendor lockdown | ? (kills clue source → chain reroutes? needs ruling) | — | shootable open? ? | — | — |
| **Scan** (RMB) | scannable while hidden; reads PROFILE FITS vs intel (funnel rule: scan never auto-IDs — confront does) ✔ | ? (R: shows alert state) | ? (R: shows ID/innocent) | ✔ via clue object | R: shows locked state + keyholder hint | R: shows route preview | R: shows route preview | — |
| **Interact** (E) | — | — | ? (barks) | ✔ clue advance | R: needs key/lockpick | R: pry open (tool? time?) | R: climb | ✔ accept bounty |
| **Noise** (gunfire, sprint) | ✔ gunfire within ~21m spooks unidentified target into flight (RULED+BUILT: loud approach forfeits the calm confrontation) | ✔ gunfire: <15m full alert, else investigate; sprint footsteps (9m): suspicion | ? (R: scatter) | ? | — | — | — | — |
| **Disguise** (TIER 1 BUILT 6/11, PLAYTEST-CONFIRMED 6/17) | fooled at range ✓ (×0.08, cap 0.4 beyond scrutiny_range 4.5m); close scrutiny thins it (×0.6, no cap) | fooled at range, breaks under close scrutiny ✓ VERIFIED 6/17 (all states: range-pass, close-alert, sprint-void, weapon-void) | R: ignored | R: still talks | — | — | — | R: board still usable |
| **Carry/drag body** (planned) | R: captured target must be carried or escorted to extraction? **BIG ruling needed** | R: hide bodies from patrols | R | — | — | R: bodies fit through grates? | R: not while carrying | — |

## Reaction rules (world-side, not player-side)

- **Guard perception (BUILT 2026-06-09):** UNAWARE → SUSPICIOUS → ALERTED state
  machine on `GangGuard` (now CharacterBody3D). Vision cone (120°, 22m, LOS ray,
  distance-scaled detect time, sprint detected 1.7× faster), hearing via the
  `perceptive` group (`hear_noise(pos, radius)`), Doom-style straight-line
  investigation movement (no navmesh), shout propagation (25m) pulling nearby
  guards into alerts, return-to-post, over-head state indicator
  (white/yellow/red/blue). Guards only FIRE when ALERTED.
- **Sentry/pressure redesign (BUILT):** the four courtyard/approach guards are
  `sentry = true`, active and UNAWARE from mission start; the extraction
  pressure wave now calls `trigger_pressure()` — same guards going ALERTED.
  Emergent ruling: guards killed during approach are absent at extraction.
  Open question for playtest: does extraction need a fresh reinforcement wave?
- **Gated routes (BUILT 2026-06-09):** doors in the `extraction_unlock` group
  sink open when the bounty is secured (BountyManager). Ruling: securing the
  target physically opens the world's back way out. First instance: courtyard
  ReturnGate → Z7 Freight Line.
- Guards investigate noise sources ✔ BUILT; discovered-body reactions NOT IMPLEMENTED.
- Civilians flee gunfire (IMPLEMENTED 6/11: NPCs damageable 50hp; gunfire panics nearby crowd + alerts guards via on_ally_alert; drawn weapon within 9m also triggers flee). District heat + vendor lockdown BUILT 6/11: civilian wounds/kills, wrong public accusations, and lethal target resolution can raise heat; at threshold, nodes in `vendor_lockdown` drop simple red shutters and toast the player. WRONG-ACCUSATION LEGIBILITY (6/17 playtest + fix): a wrong mark fired guard-alert + heat but both were invisible — guards live in the courtyard (x96-128) so the 25m `on_ally_alert` gate no-ops when accusing in the crowd, AND one wrong mark (heat +1) sat under threshold 2. Fixed `heat_wrong_accusation` 1→2 so ONE wrong mark now trips lockdown. BUT the lockdown is currently MECHANISM-ONLY: the sole `vendor_lockdown` responder (`WorldGeometry/StallsAndCover`) parents only a crate — no `Stall`/`_Counter`/`_Awning` children for `set_lockdown` to shut, and the courtyard's stalls are baked into `Hesperus_Courtyard.glb` (unreachable by name). So a wrong mark now reliably fires the heat beat (toast "the crowd turns wary" + console line) but drops NO shutters. Guard-alert still correctly fires when accusing NEAR the courtyard. CROWD CLAM-UP (added 6/17): a wrong mark now also silences bystanders — `BountyManager._on_wrong_accusation` calls `CrowdDirector.clam_up_near(accused_pos, clam_up_radius, clam_up_duration)` (exports, default 15m / 35s); each CrowdNPC within range refuses to canvass for the duration (`crowd_npc.clam_up()` sets `_clam_timer`, ticked down in `_physics_process`). While clammed: interact prompt reads "<name> won't talk after that scene" and asking yields "After that? I didn't see anything." instead of a hint. Wears off; refreshes to the longer time rather than stacking. Only affects procedural CrowdNPCs (the hand-placed `Civ_*` sprites have no canvass interaction). DEFER (Nick + Codex): place `.tscn` stall geometry under a `vendor_lockdown` node near the crowd, or move the script onto a node that parents stalls, then restore the shutter visuals + the honest "vendors locking down" toast.
- Target escape behavior ✔ (flees along `KorvaxiEscapeRoute` westward); now also
  triggered by nearby gunfire or guard shouts ✔. CHASE DEPTH (playtest note 6/17):
  the chase FIRES correctly but is a STUB — Korvaxi runs the 4-node
  `KorvaxiEscapeRoute` (all within the courtyard/east-alley) and then just stops.
  No lose-the-target / shake-pursuit mechanic, no larger pursuit space. Accepted
  as in-place-not-deep for the graybox milestone. POST-SPRINT (matches risk #2):
  build a dynamic chase over a larger area with an actual way to evade/lose the
  target; needs Nick-led chase-route layout first.
- **Disguise scrutiny (PLAYTEST-CONFIRMED 6/17):** the social route into the
  courtyard is fully working. Disguise only counts while ALSO blended (holstered
  + walking pace); the worn-garb gate is purely range-based — beyond 4.5m guards
  stay UNAWARE (×0.08 rate, 0.4 cap = can't even reach SUSPICIOUS), inside 4.5m
  the disguise thins (×0.6, no cap) and a lingering player escalates to ALERTED.
  Sprinting or drawing a weapon voids blend → disguise stops applying. A 2nd
  disguise pickup (`DisguisePickup_CourtyardApproach`, "courtyard staff
  coveralls") was placed at world (91, -0.2, -8) on the east approach so the
  social route has a garb source near the courtyard (the original is down in the
  south plaza). NOTE: first playtest read as "never escalates" — that was the
  player standing in the >4.5m range band (correct near-invisible behavior), not
  a bug; crossing inside 4.5m alerts as designed. COURTYARD HAS NO CROWD-BLEND
  (playtest note 6/17, by design): the capture arena contains only guards, no
  civilians, so crowd-blending (holstered + walk + near 2+ NPCs) is not a path
  there — disguise is the social tool for the courtyard, crowd-blend is for the
  populated bazaar/plaza/dock approaches. Two systems, two spaces; not a gap.
- Consequence propagation (payout → district reaction) is the loop's promised
  payoff and is entirely unbuilt — design doc needed before implementation.

## The two flagged risks (carried over, still true)

1. **Scanner/clue/identity system** — highest-risk, least-proven. Prototype
   before art. The scan column above is mostly unruled; that's the symptom.
2. **Chase system** — second-biggest risk; escape route works but chase feel
   needs dedicated iteration budget.

## Multiple-playthrough test

A build supports replay when, for the single Korvaxi bounty, all of these are
genuinely different runs: (a) loud front-gate assault, (b) disguise/social walk-in,
(c) balcony-or-grate silent capture with zero alerts. Each requires different
cells above to be ✔. Track readiness against this, not against prop count.
