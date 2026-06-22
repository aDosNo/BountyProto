# BOUNTY-HUNT — DESIGN VISION (locked 2026-06-10)
This is WHAT we're building. SYSTEMS_IMSIM.md = verbs, STYLE.md = look, PROJECT_MANIFEST.md = current state.

## Pitch
Retro sci-fi bounty hunter im-sim: 2–3 dense districts, a revolver, a stun rig, a net, and a scanner.
Contracts arrive at your office. Targets hide in crowds, behind locked doors, up on catwalks. Every mark
has three ways in; every botched job becomes a harder one later. Capture alive pays double.
**Hitman WoA architecture wearing Prey 2's skin at Build-engine fidelity** — few maps x many contracts
x systemic depth.

## Shape
- Districts: Hesperus Market (social/disguise), Docks (stealth/verticality), District 3 TBD (force —
  gang territory or nightlife strip).
- Loadout (final): revolver/pistol, stun gun, net capture, binoculars/scanner.
- Core loop: accept contract → investigate (clue FUNNEL, not chain) → identify → neutralize or capture
  (alive = 2x pay) → extract.

## Replayability = procedural CONTRACT generation (NOT run-based permadeath)
Shadows of Doubt model: persistent handcrafted maps, generated cases. The authored Korvaxi hunt is the
template the generator stamps. Generator samples:
- WHO: sprite pool + trait kit (build, appearance, movement_tell, location_habit, scanner_signature)
- TEMPERAMENT: skittish / guarded / social / reclusive — biases which approach is strong
- CONTRACT TYPE: alive (full pay) vs dead-or-alive (half)
- COMPLICATION: rival hunter / target has a double / bribed faction (sees through disguises) / curfew heat
- PAYOUT scaled to modifiers. Optional: staked bond on accept — dying mid-job forfeits it.

## Economy — money buys VERBS, not numbers
- Verb sinks: lockpick/decoder, grapple or mag-gloves, lures, disguise tiers, bribes (social consumable),
  faction permits, intel broker (pre-buy one trait reveal — ties economy directly into the funnel).
- Stat lines limited to: scanner range/speed/depth, net range, binocular tagging.
- Hub (office or ship): contract inbox + cosmetic sink.

## Nemesis-lite
Escaped / gone-to-ground targets re-enter the bounty pool later: harder, with a grudge and changed
traits. Implementation cost: persist one struct.

## ENGINEERING DISCIPLINE (the rule that protects all of the above)
Traits + behavior profiles live in DATA FILES (JSON / Godot Resources) — never hardcoded in scenes or
scripts. The contract generator must be a July problem, not a September rewrite.
> Resolved 6/11: pools live in `data/crowd_traits_hesperus.json` (traits, witness params, spawn quotas). Behavior profiles (temperaments) still pending — add as data when built.

## Roadmap (post-sprint estimates)
- Contract generator: 1–2 wk (funnel is already parameterized). Economy/shop: 1 wk. Faction scrutiny:
  1 wk. Nemesis-lite: days.
- Content long pole: ~1–2 months per district at target density. Sprite variety = palette swaps +
  accessory overlays on shared bases (the appearance-trait system wants this anyway).
- Early-Access-able at: 1 district + generator + economy. Districts 2–3 ship as updates. v1 ~6–12 mo.
