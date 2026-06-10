# bounty-hunt — Im-Sim Systems Contract

The im-sim promise is consistency: every verb works the same way on every object
that plausibly affords it, and the world reacts whether or not the player is the
cause. This matrix is the single place rules get decided. When implementing any
prop, NPC, or interaction, wire it against this table; if a cell is blank,
propose a ruling to Nick — do not improvise one silently.

Status legend: ✔ implemented · R = ruled (designed, not built) · ? = needs ruling

## Verb × Object matrix

| Verb ↓ / Object → | Korvaxi (target) | GangGuard | Civilian sprite NPC | Witness | Locked door (Z6 back door) | Grate / vent | Ladder / balcony | Bounty board |
|---|---|---|---|---|---|---|---|---|
| **Stun net** (capture verb) | ✔ captures, alive payout | ? (R-proposal: stuns N sec, no bounty) | ? (R-proposal: stuns, crowd panics, heat+) | ? | — | — | — | — |
| **Lethal fire** | ✔ kills, dead payout | ✔ kills | ? (R-proposal: kills, heat++, vendor lockdown) | ? (kills clue source → chain reroutes? needs ruling) | — | shootable open? ? | — | — |
| **Scan** (RMB) | reveals after clue 03 ✔ | ? (R: shows alert state) | ? (R: shows ID/innocent) | ✔ via clue object | R: shows locked state + keyholder hint | R: shows route preview | R: shows route preview | — |
| **Interact** (E) | — | — | ? (barks) | ✔ clue advance | R: needs key/lockpick | R: pry open (tool? time?) | R: climb | ✔ accept bounty |
| **Noise** (gunfire, sprint) | ✔ gunfire within ~21m spooks unidentified target into flight (RULED+BUILT: loud approach forfeits the calm confrontation) | ✔ gunfire: <15m full alert, else investigate; sprint footsteps (9m): suspicion | ? (R: scatter) | ? | — | — | — | — |
| **Disguise** (planned) | fooled at range? ? | R: fooled until close/los time | R: ignored | R: still talks | — | — | — | R: board still usable |
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
- Civilians flee gunfire; vendors close stalls under "heat" (NOT IMPLEMENTED).
- Target escape behavior ✔ (flees along `KorvaxiEscapeRoute` westward); now also
  triggered by nearby gunfire or guard shouts ✔.
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
