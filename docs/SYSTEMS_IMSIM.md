# bounty-hunt — Im-Sim Systems Contract

Reconciled against the live checkout on 2026-07-01.

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
leaves `scannable_npc` and joins `chase_target`: sweep can reacquire him during
pursuit, but analysis cannot repeat the identity step.
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
| **Scan** (RMB) — hybrid sweep/analysis (Phase C, **BUILT 6/29**) | hidden: sweep shortlists and analysis reads the signature; chase: sweep temporarily reacquires the live marker after LOS loss | sweep ignored (not `scannable_npc`); analysis = n/a | sweep lights candidates whose visible traits match known intel; analysis = full PROFILE FITS readout and costs cover | database-driven evidence is discoverable without prior intel; held analysis verifies the rumor/trace and records provenance | R: scan shows locked state + keyholder hint | R: shows route preview | R: shows route preview | — |
| **Interact** (E) | — | — | ? (barks) | ✔ creates an unverified evidence lead and zone hint | R: needs key/lockpick | R: pry open (tool? time?) | R: climb | ✔ accept bounty |
| **Noise** (gunfire, sprint) | ✔ gunfire within ~21m can spook the unidentified target only through a clear physics path; target panic uses a dedicated channel rather than generic guard perception | ✔ gunfire: <15m full alert, else investigate; sprint footsteps (9m): suspicion | ? (R: scatter) | ? | — | — | — | — |
| **Disguise** (TIER 1 BUILT 6/11, PLAYTEST-CONFIRMED 6/17) | fooled at range ✓ (×0.08, cap 0.4 beyond scrutiny_range 4.5m); close scrutiny thins it (×0.6, no cap) | fooled at range, breaks under close scrutiny ✓ VERIFIED 6/17 (all states: range-pass, close-alert, sprint-void, weapon-void) | R: ignored | R: still talks | — | — | — | R: board still usable |
| **Carry/drag body** (planned) | R: captured target must be carried or escorted to extraction? **BIG ruling needed** | R: hide bodies from patrols | R | — | — | R: bodies fit through grates? | R: not while carrying | — |

## Reaction rules (world-side, not player-side)

- **Scanner cover cost (BUILT 6/29):** held analysis
  emits a periodic suspicion ping at the focused NPC's position into the
  existing `gang_guard` perception channel as a sub-gunfire noise event
  (`loudness < 25`, raises SUSPICIOUS not ALERTED). Ping radius scales with
  `is_blended()` (blended shrinks the ping) and with hold duration (longer
  holds get louder). Sweep is free — only analysis costs cover. Implements
  `01`'s "scanning openly costs cover" rule by reusing the existing
  perception machinery rather than inventing a new stat. Numbers in
  `05_INVESTIGATION_LAYER_BRIDGE.md` §C.3.
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
- **Prepared extraction modifier (BUILT 2026-06-22):** the Freight Inspection
  Yard can be solved before capture through courier credentials, a utility
  scanner bypass, or an inspection-tower override. Confirming its dispatch plan
  joins the existing extraction sequence rather than replacing it: pressure
  activates normally, then the yard-specific reinforcement is suppressed and a
  crane container lowers into cover. Unprepared extraction keeps that guard.
- Guards investigate noise sources ✔ BUILT; discovered-body reactions NOT IMPLEMENTED.
- Civilians flee gunfire (IMPLEMENTED 6/11: NPCs damageable 50hp; gunfire panics nearby crowd + alerts guards via on_ally_alert; drawn weapon within 9m also triggers flee). District heat + vendor lockdown BUILT 6/11 and made visible at the Bazaar Safehouse 6/22: civilian wounds/kills, wrong public accusations, and lethal target resolution can raise heat; at threshold, `vendor_lockdown` responders react. One wrong mark reaches the threshold, drops the safehouse's two authored street shutters, removes its broker-terminal route, and leaves the utility and roof routes available. The legacy `WorldGeometry/StallsAndCover` responder still parents only a crate and remains visually inert. Guard-alert correctly fires when accusing near the courtyard. CROWD CLAM-UP (added 6/17): a wrong mark also silences nearby procedural CrowdNPCs for the configured duration; hand-placed sprite civilians do not participate in canvassing.
- Target escape behavior ✔; nearby
  gunfire and guard shouts now use the dedicated `target_panic_listener` channel,
  configurable radii, and solid-geometry occlusion. Lethally hit guards die
  before warning allies; the gunshot itself remains an audible event. CHASE
  INTEGRATION (built 6/29, needs first-person tuning): the public Bazaar route
  corners Korvaxi; prepared service-street, rooftop, and service-crawl branches
  can end in escape. Preparation gives both actors access, route selection is
  announced through the objective/HUD, stamina drains under close pressure, and
  wounds slow him. The live marker drops after LOS loss, leaves a last-known
  marker, and scanner sweep temporarily reacquires him.
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
- Consequence propagation is PARTIAL: heat and lockdown persist, safehouse
  shutters and freight extraction respond visibly, and contract outcome/status/
  route/preparation are recorded. Starting a new contract clears only
  `hesperus.contract.*`; completed activities, access, and heat persist, and
  their earned intel is rehydrated for the same Korvaxi contract. A broader
  post-contract NPC dialogue/faction layer remains outside this milestone.

## The two playtest gates

1. **Scanner Phase C feel** — implementation and authored-field tests pass.
   Playtest tap/hold recognition, marker readability, shortlist pacing, and
   exposed-versus-blended suspicion before tuning numbers. First repair the
   three stale modular-stall landmark references listed in
   `PROJECT_MANIFEST.md`; fallback placement currently keeps tests green while
   narrowing evidence variety.
2. **Chase feel** — route contracts and automated checks pass. Playtest route
   clearance, rooftop height transitions, LOS grace, reacquisition usefulness,
   and whether stamina produces a fair catch window.

## Multiple-playthrough test

A build supports replay when, for the single Korvaxi bounty, all of these are
genuinely different runs: (a) loud front-gate assault, (b) disguise/social walk-in,
(c) balcony-or-grate silent capture with zero alerts. Each requires different
cells above to be ✔. Track readiness against this, not against prop count.
